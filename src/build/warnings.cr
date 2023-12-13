module Crystal
  # Which warnings to detect.
  enum WarningLevel
    None
    All
  end

  # This collection handles warning detection, reporting, and related options.
  # It is shared between a `Crystal::Compiler` and other components that need to
  # produce warnings.
  class WarningCollection
    # Which kind of warnings we want to detect.
    property level : WarningLevel = :all

    # Detected warnings.
    property infos = [] of String

    # Whether the compiler will error if any warnings are detected.
    property? error_on_warnings = false

    def add_warning(node : ASTNode, message : String)
      return unless @level.all?
      @infos << node.warning(message)
    end

    def add_warning_at(location : Location?, message : String)
      return unless @level.all?
      if location
        message = String.build do |io|
          exception = SyntaxException.new message, location.line_number, location.column_number, location.filename
          exception.warning = true
          exception.append_to_s(io, nil)
        end
      end

      @infos << message
    end

    def report(io : IO)
      unless @infos.empty?
        @infos.each do |message|
          io.puts message
          io.puts "\n"
        end
        io.puts "A total of #{@infos.size} warnings were found."
      end
    end

  end

  class ASTNode
    def warning(message, inner = nil, exception_type = Crystal::TypeException)
      # TODO extract message formatting from exceptions
      String.build do |io|
        exception = exception_type.for_node(self, message, inner)
        exception.warning = true
        exception.append_to_s(io, nil)
      end
    end
  end

end
