require "option_parser"
require "file_utils"
require "colorize"
require "crystal/digest/md5"
require "llvm"

module Crystal
  @[Flags]
  enum Debug
    LineNumbers
    Variables
    Default     = LineNumbers
  end

  # Main interface to the compiler.
  #
  # A Compiler parses source code, type checks it and
  # optionally generates an executable.
  class Compiler
    private DEFAULT_LINKER = "cc"

    # A source to the compiler: its filename and source code.
    record Source,
      filename : String,
      code : String

    # The result of a compilation: the program containing all
    # the type and method definitions, and the parsed program
    # as an ASTNode.
    record Result,
      program : Program,
      node : ASTNode

    # Compiler flags. These will be true when checked in macro
    # code by the `flag?(...)` macro method.
    property flags = [] of String

    # Library paths
    property paths = [] of String

    # If `true`, the executable will be generated with debug code
    # that can be understood by `gdb` and `lldb`.
    property debug = Debug::Default

    # Sets the mcpu. Check LLVM docs to learn about this.
    property mcpu : String?

    # Sets the mattr (features). Check LLVM docs to learn about this.
    property mattr : String?

    # cache directory
    property cache = "cache"

    # If `false`, color won't be used in output messages.
    property? color = true

    # Maximum number of LLVM modules that are compiled in parallel
    property n_threads = 8

    # Default prelude file to use. This ends up adding a
    # `require "prelude"` (or whatever name is set here) to
    # the source file to compile.
    property prelude = "prelude"

    # If `true`, runs LLVM optimizations.
    property? release = false

    # Sets the code model. Check LLVM docs to learn about this.
    property mcmodel = LLVM::CodeModel::Default

    # If `true`, generates a single LLVM module. By default
    # one LLVM module is created for each type in a program.
    property? single_module = false

    # A `ProgressTracker` object which tracks compilation progress.
    property progress_tracker = ProgressTracker.new

    # If `true`, doc comments are attached to types and methods
    # and can later be used to generate API docs.
    property? wants_doc = false

    # Warning settings and all detected warnings.
    property warnings = WarningCollection.new

    @[Flags]
    enum EmitTarget
      ASM
      OBJ
      LLVM_BC
      LLVM_IR
    end

    # Can be set to a set of flags to emit other files other
    # than the executable file:
    # * asm: assembly files
    # * llvm-bc: LLVM bitcode
    # * llvm-ir: LLVM IR
    # * obj: object file
    property emit_targets : EmitTarget = EmitTarget::None

    # Base filename to use for `emit` output.
    property emit_base_filename : String?

    # Default standard output to use in a compilation.
    property stdout : IO = STDOUT

    # Default standard error to use in a compilation.
    property stderr : IO = STDERR

    # Whether to show error trace
    property? show_error_trace = false

    # Whether to link statically
    property? static = false

    # Program that was created for the last compilation.
    property! program : Program

    # Compiles the given *source*, with *output_filename* as the name
    # of the generated executable.
    #
    # Raises `Crystal::CodeError` if there's an error in the
    # source code.
    #
    # Raises `InvalidByteSequenceError` if the source code is not
    # valid UTF-8.
    def compile(source : Source | Array(Source), output_filename : String) : Result
      source = [source] unless source.is_a?(Array)
      program = new_program(source)
      node = parse program, source
      node = program.semantic node
      result = codegen program, node, source, output_filename

      @progress_tracker.clear
      print_macro_run_stats(program)
      Result.new program, node
    end

    # Runs the semantic pass on the given source, without generating an
    # executable nor analyzing methods. The returned `Program` in the result will
    # contain all types and methods. This can be useful to generate
    # API docs, analyze type relationships, etc.
    #
    # Raises `Crystal::CodeError` if there's an error in the
    # source code.
    #
    # Raises `InvalidByteSequenceError` if the source code is not
    # valid UTF-8.
    def top_level_semantic(source : Source | Array(Source)) : Result
      source = [source] unless source.is_a?(Array)
      program = new_program(source)
      node = parse program, source
      node, processor = program.top_level_semantic(node)

      @progress_tracker.clear
      print_macro_run_stats(program)

      Result.new program, node
    end

    private def new_program(sources)
      @program = program = Program.new(target_machine)
      program.filename = sources.first.filename
      program.cache = cache
      program.flags.concat(@flags)
      program.flags << "release" if release?
      program.flags << "debug" unless debug.none?
      program.flags << "static" if static?
      program.paths.concat(@paths)
      program.wants_doc = wants_doc?
      program.color = color?
      program.stdout = stdout
      program.show_error_trace = show_error_trace?
      program.progress_tracker = @progress_tracker
      program.warnings = @warnings
      program
    end

    private def parse(program, sources : Array)
      @progress_tracker.stage("Parse") do
        nodes = sources.map do |source|
          # We add the source to the list of required file,
          # so it can't be required again
          program.requires.add source.filename
          parse(program, source).as(ASTNode)
        end
        nodes = Expressions.from(nodes)

        # Prepend the prelude to the parsed program
        location = Location.new(program.filename, 1, 1)
        nodes = Expressions.new([Require.new(prelude).at(location), nodes] of ASTNode)

        # And normalize
        program.normalize(nodes)
      end
    end

    private def parse(program, source : Source)
      parser = program.new_parser(source.code)
      parser.filename = source.filename
      parser.wants_doc = wants_doc?
      parser.parse
    rescue ex : InvalidByteSequenceError
      stderr.print colorize("Error: ").red.bold
      stderr.print colorize("file '#{Crystal.relative_filename(source.filename)}' is not a valid Crystal source file: ").bold
      stderr.puts ex.message
      exit 1
    end

    # Returns the directory where cache files related to the
    # given filenames will be stored. The directory will be
    # created if it doesn't exist.
    private def directory_for(filename : String)
      filename = ::Path[filename]
      name = String.build do |io|
        filename.each_part do |part|
          if io.empty?
            if part == "#{filename.anchor}"
              part = "#{filename.drive}"[..0]
            end
          else
            io << '-'
          end
          io << part
        end
      end
      output_dir = File.join(cache, name)
      Dir.mkdir_p(output_dir)
      output_dir
    end

    # Returns the directory where cache files related to the
    # given sources will be stored. The directory will be
    # created if it doesn't exist.
    private def directory_for(sources : Array(Compiler::Source))
      directory_for(sources.first.filename)
    end

    private def codegen(program, node : ASTNode, sources, output_filename)

      output_dir = directory_for(sources)
      @progress_tracker.clear
      llvm_modules = @progress_tracker.stage("Codegen (llvm modules)") do
        program.codegen node, debug: debug, single_module: @single_module || @release || !@emit_targets.none?
      end

      target_triple = target_machine.triple

      units = llvm_modules.map do |type_name, info|
        llvm_mod = info.mod
        llvm_mod.target = target_triple
        CompilationUnit.new(self, program, type_name, llvm_mod, output_dir)
      end

      result = with_file_lock(output_dir) do
        codegen program, units, output_filename, output_dir
      end
      result
    end

    private def with_file_lock(output_dir, &)
      File.open(File.join(output_dir, "compiler.lock"), "w") do |file|
        file.flock_exclusive do
          yield
        end
      end
    end

    private def linker_command(program : Program, object_names, output_filename, output_dir, expand = false)
        link_flags = " -rdynamic"
        {DEFAULT_LINKER, %(#{DEFAULT_LINKER} "${@}" -o #{Process.quote_posix(output_filename)} #{link_flags} #{program.lib_flags}), object_names}
    end

    private def codegen(program, units : Array(CompilationUnit), output_filename, output_dir)
      object_names = units.map &.object_filename

      target_triple = target_machine.triple
      reused = [] of String

      @progress_tracker.stage("Codegen (object files)") do
        @progress_tracker.stage_progress_total = units.size

        if units.size == 1
          first_unit = units.first
          first_unit.compile
          first_unit.emit(@emit_targets, emit_base_filename || output_filename)
        else
          reused = codegen_many_units(program, units, target_triple)
        end
      end

      # We check again because maybe this directory was created in between (maybe with a macro run)
      if Dir.exists?(output_filename)
        error "can't use `#{output_filename}` as output filename because it's a directory"
      end

      output_filename = File.expand_path(output_filename)

      @progress_tracker.stage("Codegen (linking)") do
        Dir.cd(output_dir) do
          run_linker *linker_command(program, object_names, output_filename, output_dir, expand: true)
        end
      end

      {units, reused}
    end

    private def codegen_many_units(program, units, target_triple)
      all_reused = [] of String

      # If threads is 1 and no stats/progress is needed we can avoid
      # fork/spawn/channels altogether. This is particularly useful for
      # CI because there forking eventually leads to "out of memory" errors.
      if @n_threads == 1
        units.each do |unit|
          unit.compile
          all_reused << unit.name if @progress_tracker.progress? && unit.reused_previous_compilation?
        end
        return all_reused
      end

      {% if !Crystal::System::Process.class.has_method?("fork") %}
        raise "Cannot fork compiler. `Crystal::System::Process.fork` is not implemented on this system."
      {% else %}
        jobs_count = 0
        wait_channel = Channel(Array(String)).new(@n_threads)

        units.each_slice(Math.max(units.size // @n_threads, 1)) do |slice|
          jobs_count += 1
          spawn do
            # For stats output we want to count how many previous
            # .o files were reused, mainly to detect performance regressions.
            # Because we fork, we must communicate using a pipe.
            reused = [] of String
            if @progress_tracker.progress?
              pr, pw = IO.pipe
              spawn do
                pr.each_line do |line|
                  unit = JSON.parse(line)
                  reused << unit["name"].as_s if unit["reused"].as_bool
                  @progress_tracker.stage_progress += 1
                end
              end
            end

            codegen_process = Crystal::System::Process.fork do
              pipe_w = pw
              slice.each do |unit|
                unit.compile
                if pipe_w
                  unit_json = {name: unit.name, reused: unit.reused_previous_compilation?}.to_json
                  pipe_w.puts unit_json
                end
              end
            end
            Process.new(codegen_process).wait

            if pipe_w = pw
              pipe_w.close
              Fiber.yield
            end

            wait_channel.send reused
          end
        end

        jobs_count.times do
          reused = wait_channel.receive
          all_reused.concat(reused)
        end

        all_reused
      {% end %}
    end

    private def print_macro_run_stats(program)
      return unless @progress_tracker.progress?
      return if program.compiled_macros_cache.empty?

      puts
      puts "Macro runs:"
      program.compiled_macros_cache.each do |filename, compiled_macro_run|
        print " - "
        print filename
        print ": "
        if compiled_macro_run.reused
          print "reused previous compilation (#{compiled_macro_run.elapsed})"
        else
          print compiled_macro_run.elapsed
        end
        puts
      end
    end

    getter(target_machine : LLVM::TargetMachine) do
      architecture = Build::TARGET.split('-',3)[0]
      cpu = ""
      features = ""
      case architecture
      when "i386", "x86_64"
        LLVM.init_x86
      when "aarch64"
        LLVM.init_aarch64
      when "arm"
        LLVM.init_arm
        # Enable most conservative FPU for hard-float capable targets, unless a
        # CPU is defined (it will most certainly enable a better FPU) or
        # features contains a floating-point definition.
        if cpu.empty? && !features.includes?("fp")
          features += "+vfp2"
        end
      else
        raise Error.new("Unsupported architecture for target triple: #{target_machine.to_s}")
      end

      opt_level = release? ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None
      code_model = LLVM::CodeModel::Default

      target = LLVM::Target.from_triple(Build::TARGET)
      machine = target.create_target_machine(Build::TARGET, cpu: cpu, features: features, opt_level: opt_level, code_model: code_model).not_nil!
      # We need to disable global isel until https://reviews.llvm.org/D80898 is released,
      # or we fixed generating values for 0 sized types.
      # When removing this, also remove it from the ABI specs and jit compiler.
      # See https://github.com/crystal-lang/crystal/issues/9297#issuecomment-636512270
      # for background info
      machine.enable_global_isel = false
      machine
    rescue ex : ArgumentError
      stderr.print colorize("Error: ").red.bold
      stderr.print "llc: "
      stderr.puts ex.message
      exit 1
    end

    {% if LibLLVM::IS_LT_130 %}
      protected def optimize(llvm_mod)
        fun_pass_manager = llvm_mod.new_function_pass_manager
        pass_manager_builder.populate fun_pass_manager
        fun_pass_manager.run llvm_mod
        module_pass_manager.run llvm_mod
      end

      @module_pass_manager : LLVM::ModulePassManager?

      private def module_pass_manager
        @module_pass_manager ||= begin
          mod_pass_manager = LLVM::ModulePassManager.new
          pass_manager_builder.populate mod_pass_manager
          mod_pass_manager
        end
      end

      @pass_manager_builder : LLVM::PassManagerBuilder?

      private def pass_manager_builder
        @pass_manager_builder ||= begin
          registry = LLVM::PassRegistry.instance
          registry.initialize_all

          builder = LLVM::PassManagerBuilder.new
          builder.opt_level = 3
          builder.size_level = 0
          builder.use_inliner_with_threshold = 275
          builder
        end
      end
    {% else %}
      protected def optimize(llvm_mod)
        LLVM::PassBuilderOptions.new do |options|
          LLVM.run_passes(llvm_mod, "default<O3>", target_machine, options)
        end
      end
    {% end %}

    private def run_linker(linker_name, command, args)
      begin
        Process.run(command, args, shell: true,
          input: Process::Redirect::Close, output: Process::Redirect::Inherit, error: Process::Redirect::Pipe) do |process|
          process.error.each_line(chomp: false) do |line|
            hint_string = colorize("(this usually means you need to install the development package for lib\\1)").yellow.bold
            line = line.gsub(/cannot find -l(\S+)\b/, "cannot find -l\\1 #{hint_string}")
            line = line.gsub(/unable to find library -l(\S+)\b/, "unable to find library -l\\1 #{hint_string}")
            line = line.gsub(/library not found for -l(\S+)\b/, "library not found for -l\\1 #{hint_string}")
            STDERR << line
          end
        end
      rescue exc : File::AccessDeniedError | File::NotFoundError
        linker_not_found exc.class, linker_name
      end

      status = $?
      unless status.success?
        if status.normal_exit?
          case status.exit_code
          when 126
            linker_not_found File::AccessDeniedError, linker_name
          when 127
            linker_not_found File::NotFoundError, linker_name
          end
        end
        code = status.normal_exit? ? status.exit_code : 1
        error "execution of command failed with exit status #{status}: #{command}", exit_code: code
      end
    end

    private def linker_not_found(exc_class, linker_name)
      case exc_class
      when File::AccessDeniedError
        error "Could not execute linker: `#{linker_name}`: Permission denied"
      else
        error "Could not execute linker: `#{linker_name}`: File not found"
      end
    end

    private def error(msg, exit_code = 1)
      Crystal.error msg, @color, exit_code, stderr: stderr
    end

    private def colorize(obj)
      obj.colorize.toggle(@color)
    end

    # An LLVM::Module with information to compile it.
    class CompilationUnit
      getter compiler
      getter name
      getter original_name
      getter llvm_mod
      getter? reused_previous_compilation = false
      getter object_extension = ".o"

      def initialize(@compiler : Compiler, program : Program, @name : String,
                     @llvm_mod : LLVM::Module, @output_dir : String)
        @name = "_main" if @name == ""
        @original_name = @name
        @name = String.build do |str|
          @name.each_char do |char|
            case char
            when 'a'..'z', '0'..'9', '_'
              str << char
            when 'A'..'Z'
              # Because OSX has case insensitive filenames, try to avoid
              # clash of 'a' and 'A' by using 'A-' for 'A'.
              str << char << '-'
            else
              str << char.ord
            end
          end
        end

        if @name.size > 50
          # 17 chars from name + 1 (dash) + 32 (md5) = 50
          @name = "#{@name[0..16]}-#{::Crystal::Digest::MD5.hexdigest(@name)}"
        end
      end

      def compile
        compile_to_object
      end

      private def compile_to_object
        bc_name = self.bc_name
        object_name = self.object_name
        temporary_object_name = self.temporary_object_name

        # To compile a file we first generate a `.bc` file and then
        # create an object file from it. These `.bc` files are stored
        # in the cache directory.
        #
        # However, instead of directly generating the final `.o` file
        # from the `.bc` file, we generate it to a temporary name (`.o.tmp`)
        # and then we rename that file to `.o`. We do this because the compiler
        # could be interrupted while the `.o` file is being generated, leading
        # to a corrupted file that later would cause compilation issues.
        # Moving a file is an atomic operation so no corrupted `.o` file should
        # be generated.

        memory_buffer = llvm_mod.write_bitcode_to_memory_buffer

        # If there's a memory buffer, it means we must create a .o from it
        if memory_buffer
          # Delete existing .o file. It cannot be used anymore.
          File.delete?(object_name)
          # Create the .bc file (for next compilations)
          ###File.write(bc_name, memory_buffer.to_slice)
          memory_buffer.dispose
        end

        compiler.optimize llvm_mod if compiler.release?
        compiler.target_machine.emit_obj_to_file llvm_mod, temporary_object_name
        File.rename(temporary_object_name, object_name)
      end

      def emit(emit_targets : EmitTarget, output_filename)
        puts "\n#{emit_targets.to_s}\n"
        if emit_targets.asm?
          compiler.target_machine.emit_asm_to_file llvm_mod, "#{output_filename}.s"
        end
        if emit_targets.llvm_bc?
          FileUtils.cp(bc_name, "#{output_filename}.bc")
        end
        if emit_targets.obj?
          FileUtils.cp(object_name, output_filename + @object_extension)
        end
      end

      def object_name
        Crystal.relative_filename("#{@output_dir}/#{object_filename}")
      end

      def object_filename
        @name + @object_extension
      end

      def temporary_object_name
        Crystal.relative_filename("#{@output_dir}/#{object_filename}.tmp")
      end

      def bc_name
        "#{@output_dir}/#{@name}.bc"
      end

      def ll_name
        "#{@output_dir}/#{@name}.ll"
      end
    end
  end
end
