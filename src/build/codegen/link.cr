module Crystal
  struct LinkAnnotation
    getter lib : String?
    getter pkg_config : String?
    getter ldflags : String?
    getter framework : String?
    getter dll : String?

    def initialize(@lib = nil, @pkg_config = @lib, @ldflags = nil, @static = false, @framework = nil, @dll = nil)
    end

    def static?
      @static
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if args.empty? && !named_args
        ann.raise "missing link arguments: must at least specify a library name"
      end

      lib_name = nil
      lib_ldflags = nil
      lib_static = false
      lib_framework = nil
      lib_dll = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "'lib' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_name = arg.value
        when 1
          arg.raise "'ldflags' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_ldflags = arg.value
        when 2
          arg.raise "'static' link argument must be a Bool" unless arg.is_a?(BoolLiteral)
          lib_static = arg.value
        when 3
          arg.raise "'framework' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_framework = arg.value
        else
          ann.wrong_number_of "link arguments", args.size, "1..4"
        end

        count += 1
      end

      named_args.try &.each do |named_arg|
        value = named_arg.value

        case named_arg.name
        when "lib"
          named_arg.raise "'lib' link argument already specified" if count > 0
          named_arg.raise "'lib' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_name = value.value
        when "ldflags"
          named_arg.raise "'ldflags' link argument already specified" if count > 1
          named_arg.raise "'ldflags' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_ldflags = value.value
        when "static"
          named_arg.raise "'static' link argument already specified" if count > 2
          named_arg.raise "'static' link argument must be a Bool" unless value.is_a?(BoolLiteral)
          lib_static = value.value
        when "framework"
          named_arg.raise "'framework' link argument already specified" if count > 3
          named_arg.raise "'framework' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_framework = value.value
        when "pkg_config"
          named_arg.raise "'pkg_config' link argument must be a String" unless value.is_a?(StringLiteral)
          #lib_pkg_config = value.value
        when "dll"
          named_arg.raise "'dll' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_dll = value.value
          unless lib_dll.size >= 4 && lib_dll[-4..].compare(".dll", case_insensitive: true) == 0
            named_arg.raise "'dll' link argument must use a '.dll' file extension"
          end
          if ::Path.separators(::Path::Kind::WINDOWS).any? { |separator| lib_dll.includes?(separator) }
            named_arg.raise "'dll' link argument must not include directory separators"
          end
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
        end
      end

      new(lib_name, nil, lib_ldflags, lib_static, lib_framework, lib_dll)
    end
  end

  class Program
    def lib_flags
      flags = [] of String
      static_build = has_flag?("static")

      # Instruct the linker to link statically if the user asks
      flags << "-static" if static_build

      # Add library paths, so the linker preferentially
      # searches user-given library paths.
      @paths.each do |path|
        flags << Process.quote_posix("-L#{path}")
      end

      link_annotations.reverse_each do |ann|
        if ldflags = ann.ldflags
          flags << ldflags
        end
        if lib_name = ann.lib
          flags << Process.quote_posix("-l#{lib_name}")
        end
        if framework = ann.framework
          flags << "-framework" << Process.quote_posix(framework)
        end
      end

      flags.join(" ")
    end

    # Returns every @[Link] annotation in the program parsed as `LinkAnnotation`
    def link_annotations
      annotations = [] of LinkAnnotation
      add_link_annotations @types, annotations
      annotations
    end

    private def add_link_annotations(types, annotations)
      types.try &.each_value do |type|
        next if type.is_a?(AliasType) || type.is_a?(TypeDefType)

        if type.is_a?(LibType) && type.used? && (link_annotations = type.link_annotations)
          annotations.concat link_annotations
        end

        add_link_annotations type.types?, annotations
      end
    end
  end
end
