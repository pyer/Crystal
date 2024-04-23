
class Exception
  getter __tinytest_file : String?
  getter __tinytest_line : Int32?

  def initialize(@message : String? = nil, @cause : Exception? = nil, @__tinytest_file = __FILE__, @__tinytest_line = __LINE__)
    # NOTE: hack to report the source location that raised
  end

  def __tinytest_location : String
    "#{__tinytest_file}:#{__tinytest_line}"
  end
end

module Tinytest
  module LocationFilter
    def __tinytest_file : String
      file, cwd = @__tinytest_file.to_s, Dir.current
      file.starts_with?(cwd) ? file[(cwd.size + 1)..-1] : file
    end
  end

  # Decorator for the original exception.
  class UnexpectedError < Exception
    include LocationFilter

    getter exception : Exception

    def initialize(@exception)
      super "#{exception.class.name}: #{exception.message}"
      @__tinytest_file = exception.__tinytest_file
    end

    def backtrace : Array(String)
      if pos = exception.backtrace.index(&.index("@Tinytest::Test#run_tests"))
        exception.backtrace[0...pos]
      else
        exception.backtrace
      end
    end

    def __tinytest_location : String
      "#{__tinytest_file}:#{exception.__tinytest_line}"
    end
  end

  class Assertion < Exception
    include LocationFilter
  end

  class Skip < Exception
    include LocationFilter
  end

end
