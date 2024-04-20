require "option_parser"
require "file_utils"
require "colorize"
require "digest/md5"
require "llvm"

module Crystal
  @[Flags]
  enum Debug
    LineNumbers
    Variables
    Default     = LineNumbers
  end

  enum FramePointers
    Auto
    Always
    NonLeaf
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

    # Controls generation of frame pointers.
    property frame_pointers = FramePointers::Auto

    # If `true`, the executable will be generated with debug code
    # that can be understood by `gdb` and `lldb`.
    property debug = Debug::Default

    # Additional link flags to pass to the linker.
    property link_flags = " -rdynamic"

    # Sets the mcpu. Check LLVM docs to learn about this.
    property mcpu : String?

    # Sets the mattr (features). Check LLVM docs to learn about this.
    property mattr : String?

    # cache directory
    property cache = Build::CACHE

    # If `false`, color won't be used in output messages.
    property? color = true

    # Maximum number of LLVM modules that are compiled in parallel
    #property n_threads : Int32 = {% if flag?(:preview_mt) || flag?(:win32) %} 1 {% else %} 8 {% end %}
    property n_threads : Int32 = 8

    # Default prelude file to use. This ends up adding a
    # `require "prelude"` (or whatever name is set here) to
    # the source file to compile.
    property prelude = "prelude"

    # Optimization mode
    enum OptimizationMode
      # [default] no optimization, fastest compilation, slowest runtime
      O0 = 0
      # low, compilation slower than O0, runtime faster than O0
      O1 = 1
      # middle, compilation slower than O1, runtime faster than O1
      O2 = 2
      # high, slowest compilation, fastest runtime
      # enables with --release flag
      O3 = 3
    end

    # Sets the Optimization mode.
    property optimization_mode = OptimizationMode::O0

    # If `true`, runs LLVM optimizations.
    property? release = false

    # Sets the code model. Check LLVM docs to learn about this.
    property mcmodel = LLVM::CodeModel::Default

    # If `true`, generates a single LLVM module. By default
    # one LLVM module is created for each type in a program.
    # --release automatically enable this option
    property? single_module = false

    # A `ProgressTracker` object which tracks compilation progress.
    property progress_tracker = ProgressTracker.new

    # Warning settings and all detected warnings.
    property warnings = WarningCollection.new

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

    # Compiles the given *source*, with *output_filename* as the name of the generated executable.
    # Raises `Crystal::CodeError` if there's an error in the source code.
    # Raises `InvalidByteSequenceError` if the source code is not valid UTF-8.
    def compile_and_link(source : Source | Array(Source), output_filename : String) : Result
      source = [source] unless source.is_a?(Array)
      if release?
        @optimization_mode = OptimizationMode::O3
        @single_module = true
      end
      program = new_program(source)
      node = parse program, source
      node = program.semantic node
      codegen program, node, source, output_filename

      @progress_tracker.clear
      print_macro_run_stats(program)
      Result.new program, node
    end

    private def new_program(sources)
      @program = program = Program.new(target_machine)
#      @program = program = Program.new()
      program.filename = sources.first.filename
      program.cache = cache
      program.flags.concat(@flags)
      program.flags << "release" if release?
      program.flags << "debug" unless debug.none?
      program.flags << "static" if static?
      program.paths.concat(@paths)
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
      name = ::Path[filename].expand.to_s.gsub('/', '-').lchop
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
        program.codegen node, debug: debug, single_module: @single_module || @release
      end

      target_triple = target_machine.triple

      units = llvm_modules.map do |type_name, info|
        llvm_mod = info.mod
        llvm_mod.target = target_triple
        CompilationUnit.new(self, program, type_name, llvm_mod, output_dir)
      end

      with_file_lock(output_dir) do
        codegen program, units, output_filename, output_dir
      end
    end

    private def with_file_lock(output_dir, &)
      File.open(File.join(output_dir, "compiler.lock"), "w") do |file|
        file.flock_exclusive do
          yield
        end
      end
    end

    private def linker_command(program : Program, object_names, output_filename, output_dir, expand = false)
        {DEFAULT_LINKER, %(#{DEFAULT_LINKER} "${@}" -o #{Process.quote_posix(output_filename)} #{link_flags} #{program.lib_flags}), object_names}
    end

    private def codegen(program, units : Array(CompilationUnit), output_filename, output_dir)
      object_names = units.map &.object_filename

      target_triple = target_machine.triple

      @progress_tracker.stage("Codegen (object files)") do
        @progress_tracker.stage_progress_total = units.size
#        units.each do |unit|
#          unit.compile
#          @progress_tracker.stage_progress += 1
#        end
        codegen_many_units(program, units, target_triple)
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
      {units}
    end

    private def codegen_many_units(program, units, target_triple)
      # Don't start more processes than compilation units
      n_threads = @n_threads.clamp(1..units.size)

      # If threads is 1 we can avoid fork/spawn/channels altogether. This is
      # particularly useful for CI because there forking eventually leads to
      # "out of memory" errors.
      if n_threads == 1
        units.each do |unit|
          unit.compile
        end
      else

        workers = fork_workers(n_threads) do |input, output|
          while i = input.gets(chomp: true).presence
            unit = units[i.to_i]
            unit.compile
            result = {name: unit.name}
            output.puts result.to_json
          end
        end

        overqueue = 1
        indexes = Atomic(Int32).new(0)
        channel = Channel(String).new(n_threads)
        completed = Channel(Nil).new(n_threads)

        workers.each do |pid, input, output|
          spawn do
            overqueued = 0

            overqueue.times do
              if (index = indexes.add(1)) < units.size
                input.puts index
                overqueued += 1
              end
            end

            while (index = indexes.add(1)) < units.size
              input.puts index

              response = output.gets(chomp: true).not_nil!
              channel.send response
            end

            overqueued.times do
              response = output.gets(chomp: true).not_nil!
              channel.send response
            end

            input << '\n'
            input.close
            output.close

            Process.new(pid).wait
            completed.send(nil)
          end
        end

        spawn do
          n_threads.times { completed.receive }
          channel.close
        end

        while response = channel.receive?
          @progress_tracker.stage_progress += 1
        end
      end
    end

    private def fork_workers(n_threads)
      workers = [] of {Int32, IO::FileDescriptor, IO::FileDescriptor}

      n_threads.times do
        iread, iwrite = IO.pipe
        oread, owrite = IO.pipe

        iwrite.flush_on_newline = true
        owrite.flush_on_newline = true

        pid = Crystal::System::Process.fork do
          iwrite.close
          oread.close

          yield iread, owrite

          iread.close
          owrite.close
          exit 0
        end

        iread.close
        owrite.close

        workers << {pid, iwrite, oread}
      end

      workers
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
        print compiled_macro_run.elapsed
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
        raise Exception.new("Unsupported architecture for target triple: #{target_machine.to_s}")
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
          case optimization_mode
          in .o3?
            builder.opt_level = 3
            builder.use_inliner_with_threshold = 275
          in .o2?
            builder.opt_level = 2
            builder.use_inliner_with_threshold = 275
          in .o1?
            builder.opt_level = 1
            builder.use_inliner_with_threshold = 150
          in .o0?
            # default behaviour, no optimizations
          end
          builder.size_level = 0
          builder
        end
      end
    {% else %}
      protected def optimize(llvm_mod)
        LLVM::PassBuilderOptions.new do |options|
          mode = case @optimization_mode
                 in .o3? then "default<O3>"
                 in .o2? then "default<O2>"
                 in .o1? then "default<O1>"
                 in .o0? then "default<O0>"
                 end
          LLVM.run_passes(llvm_mod, mode, target_machine, options)
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
      getter llvm_mod
      getter object_extension = ".o"

      def initialize(@compiler : Compiler, program : Program, @name : String,
                     @llvm_mod : LLVM::Module, @output_dir : String)
        @name = "_main" if @name == ""
        @name = String.build do |str|
          @name.each_char do |char|
            case char
            when 'a'..'z', '0'..'9', '_'
              str << char
            when 'A'..'Z'
              # Because OSX has case insensitive filenames, try to avoid
              # clash of 'a' and 'A' by using 'A-' for 'A'.
              #str << char << '-'
              str << char
            when ':', '@', ','
              str << char
            when ' '
              str << '_'
            when '('
              str << '{'
            when ')'
              str << '}'
            else
              str << char.ord
            end
          end
        end

        if @name.size > 50
          # 17 chars from name + 1 (dash) + 32 (md5) = 50
          @name = "#{@name[0..16]}-#{Digest::MD5.hexdigest(@name)}"
        end
      end

      def compile
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

        compiler.optimize llvm_mod unless compiler.optimization_mode.o0?
        compiler.target_machine.emit_obj_to_file llvm_mod, temporary_object_name
        File.rename(temporary_object_name, object_name)

        llvm_mod.print_to_file ll_name unless compiler.debug.none?
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
