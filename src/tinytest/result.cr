module Tinytest
  class Result
    getter assertions : Int64
    getter failures : Array(Assertion | Skip | UnexpectedError)
    getter name : String
    property! time : Time::Span

    def initialize(@name : String)
      @assertions = 0
      @failures = [] of Assertion | Skip | UnexpectedError
    end

    def success
      @message = "OK"
    end

    def passed? : Bool
      failures.empty?
    end

    def skipped? : Bool
      failures.any?(Skip)
    end

    def result_code : Char
      if passed?
        '.'
      elsif skipped?
        'S'
      elsif failures.any?(Assertion)
        'F'
      else
        'E'
      end
    end

    def failure : Assertion | Skip | UnexpectedError
      failures.first
    end

    def report
        message = "OK"
        message = failure.message unless passed?
        puts "  - " + @name + " : " + message
    end
  end
end

