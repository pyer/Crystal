require "./error"

module Crystal
  struct CrystalPath
    class NotFoundError < Crystal::Error
      getter filename
      getter relative_to

      def initialize(@filename : String, @relative_to : String?)
      end
    end

    # Expand `$ORIGIN` in the paths to the directory where the compiler binary
    # is located (at runtime).
    # For install locations like
    #    `/path/prefix/bin/crystal`         for the compiler
    #    `/path/prefix/share/crystal/src`   for the standard library
    # the path `$ORIGIN/../share/crystal/src` resolves to
    # the standard library location.
    # This generic path can be passed into the compiler via CRYSTAL_CONFIG_PATH
    # to produce a portable binary that resolves the standard library path
    # relative to the compiler location, independent of the absolute path.
    def self.expand_paths(paths, origin)
      paths.map! do |path|
        if (chopped = path.lchop?("$ORIGIN")) && chopped[0].in?(::Path::SEPARATORS)
          if origin.nil?
            raise "Missing executable path to expand $ORIGIN path"
          end
          File.join(origin, chopped)
        else
          path
        end
      end
    end

    def self.expand_paths(paths)
      origin = nil
      if executable_path = Process.executable_path
        origin = File.dirname(executable_path)
      end
      expand_paths(paths, origin)
    end

    property library_paths : Array(String)

    def initialize(paths : Array(String))
      @library_paths = paths
      @current_dir = Dir.current
    end

    def find_file(filename, relative_to = nil) : Array(String)
      relative_to = File.dirname(relative_to) if relative_to.is_a?(String)

      if filename.starts_with? '.'
        result = find_in_path_relative_to_dir(filename, relative_to)
      else
        result = find_in_crystal_path(filename)
      end

      unless result
        raise NotFoundError.new(filename, relative_to)
      end

      result = [result] if result.is_a?(String)
      result
    end

    private def find_in_path_relative_to_dir(filename, relative_to)
      return unless relative_to.is_a?(String)

      # Check if it's a wildcard.
      if filename.ends_with?("/*") || (recursive = filename.ends_with?("/**"))
        filename_dir_index = filename.rindex('/').not_nil!
        filename_dir = filename[0..filename_dir_index]
        relative_dir = "#{relative_to}/#{filename_dir}"
        if File.exists?(relative_dir)
          files = [] of String
          gather_dir_files(relative_dir, files, recursive)
          return files
        end

        return nil
      end

      each_file_expansion(filename, relative_to) do |path|
        absolute_path = File.expand_path(path, dir: @current_dir)
        return absolute_path if File.file?(absolute_path)
      end

      nil
    end

    def each_file_expansion(filename, relative_to, &)
      relative_path = "#{relative_to}/#{filename}"
      # Check if .cr file exists.
      yield relative_path.ends_with?(".cr") ? relative_path : "#{relative_path}.cr"

      filename_is_relative = filename.starts_with?('.')

      shard_name, _, shard_path = filename.partition("/")
      shard_path = shard_path.presence

      if !filename_is_relative && shard_path
        shard_src = "#{relative_to}/#{shard_name}/src"
        shard_path_stem = shard_path.rchop(".cr")

        # If it's "foo/bar/baz", check if "foo/src/bar/baz.cr" exists (for a shard, non-namespaced structure)
        yield "#{shard_src}/#{shard_path_stem}.cr"

        # Then check if "foo/src/foo/bar/baz.cr" exists (for a shard, namespaced structure)
        yield "#{shard_src}/#{shard_name}/#{shard_path_stem}.cr"

        # If it's "foo/bar/baz", check if "foo/bar/baz/baz.cr" exists (std, nested)
        basename = File.basename(relative_path, ".cr")
        yield "#{relative_path}/#{basename}.cr"

        # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, non-namespaced, nested)
        yield "#{shard_src}/#{shard_path}/#{shard_path_stem}.cr"

        # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, namespaced, nested)
        yield "#{shard_src}/#{shard_name}/#{shard_path}/#{shard_path_stem}.cr"
      else
        basename = File.basename(relative_path, ".cr")

        # If it's "foo", check if "foo/foo.cr" exists (for the std, nested)
        yield "#{relative_path}/#{basename}.cr"

        unless filename_is_relative
          # If it's "foo", check if "foo/src/foo.cr" exists (for a shard)
          yield "#{relative_path}/src/#{basename}.cr"
        end
      end
    end

    private def gather_dir_files(dir, files_accumulator, recursive)
      files = [] of String
      dirs = [] of String

      Dir.each_child(dir) do |filename|
        full_name = "#{dir}/#{filename}"

        if File.directory?(full_name)
          if recursive
            dirs << filename
          end
        else
          if filename.ends_with?(".cr")
            files << full_name
          end
        end
      end

      files.sort!
      dirs.sort!

      files.each do |file|
        files_accumulator << File.expand_path(file, dir: @current_dir)
      end

      dirs.each do |subdir|
        gather_dir_files("#{dir}/#{subdir}", files_accumulator, recursive)
      end
    end

    private def find_in_crystal_path(filename)
      @library_paths.each do |path|
        required = find_in_path_relative_to_dir(filename, path)
        return required if required
      end

      nil
    end
  end
end
