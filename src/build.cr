# This is the main file that is compiled to generate the executable for the compiler.

module Build
  VERSION      = "2.0.2"
  # LLVM_VERSION = {{ `llvm-config --version` }}
  LLVM_VERSION = "17.0.6"
  TARGET       = "x86_64-linux-gnu"
  # PATH         = "/usr/lib/build"
  PATH_SRC       = "/usr/share/crystal/src"
  PATH_LIB       = "/usr/share/crystal/src/lib_c/x86_64-linux-gnu"
  BUILD_DATE   = {{ `date +'"%Y-%m-%d %H:%M:%S"'` }}
end

require "json"

require "./build/annotatable"
require "./build/codegen/*"
require "./build/compiler"
require "./build/crystal_path"
require "./build/macros"
require "./build/program"
require "./build/progress_tracker"
require "./build/syntax"

source_filenames = [] of String
output_filename  = ""

quiet = false;

    # Create compiler
    compiler = Crystal::Compiler.new
    compiler.progress_tracker = Crystal::ProgressTracker.new
    # Default options
    compiler.color = false
    compiler.debug = Crystal::Debug::None
    compiler.flags = Build::TARGET.split("-")
    compiler.flags << "unix"
    compiler.flags << "bits64"
    compiler.paths = [Build::PATH_SRC, Build::PATH_LIB]
    compiler.single_module = false
    compiler.static = false

    # Here we process the compiler's command line options
    option_parser = OptionParser.parse(ARGV) do |opts|
      opts.banner = "Usage: build [options] [source.cr]\n\nOptions:"

      opts.on("-v", "--version", "Version") do
        # ruby 2.7.0p0 (2019-12-25 revision 647ee6f091) [x86_64-linux-gnu]
        puts "build #{Build::VERSION} (#{Build::BUILD_DATE}) [#{Build::TARGET}]"
        exit
      end
      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on("-c", "--color", "Colorize output") do
        compiler.color = true
      end
      opts.on("-d", "--debug", "Add full symbolic debug info") do
        compiler.debug = Crystal::Debug::All
      end
      opts.on("-D FLAG", "--define FLAG", "Define a compiler flag") do |flag|
        compiler.flags << flag
      end
      opts.on("-L PATH", "--library PATH", "Add a library path") do |path|
        compiler.paths << path
      end

      opts.on("-o", "--output ", "Output filename") do |an_output_filename|
          output_filename = an_output_filename
      end
      opts.on("-p", "--progress", "Enable progress output") do
        compiler.progress_tracker.progress = true
      end
      opts.on("-q", "--quiet", "Compile in quiet mode") do
        quiet = true
      end
      opts.on("-r", "--release", "Compile in release mode") do
        compiler.release = true
      end
      opts.on("-s", "--static", "Link statically") do
        compiler.static = true
      end
      opts.on("-t", "--trace", "Show full error trace") do
        compiler.show_error_trace = true
      end

      opts.unknown_args do |before|
        source_filenames = before
      end
    end

unless quiet
  # Show environment
  puts "Version #{Build::VERSION} (#{Build::BUILD_DATE})"
  puts "LLVM    #{Build::LLVM_VERSION}"
  puts "Target  #{Build::TARGET}"
  puts "Flags   #{compiler.flags.to_s}"
  puts "Paths   #{compiler.paths.to_s}"
  puts ""
end

# Check arguments
Exception.new "Source file absent" if source_filenames.size == 0

source_filenames.each do |filename|
    Exception.new "File '#{filename}' not found" unless File.file?(filename)
    source_name = File.expand_path(filename)
    source = Crystal::Compiler::Source.new(filename, File.read(filename))

    if output_filename.empty?
      file_ext = File.extname(source_name)
      output_filename = File.basename(source_name, file_ext)
    end
    Exception.new "Can't use '#{output_filename}' as output filename because it's a directory" if Dir.exists?(output_filename)

    # Check if we'll overwrite the main source file
    Exception.new "Compilation will overwrite source file '#{source_name}'" if source_name == File.expand_path(output_filename)

    # Let's go
    puts "Compiling #{source_name} to #{output_filename}" unless quiet
    compiler.compile_and_link source, output_filename
end
puts "Elapsed time : #{compiler.progress_tracker.elapsed_time}" unless quiet
