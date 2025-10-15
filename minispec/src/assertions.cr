module MiniSpec

  class AssertionFailed < Exception
    getter file : String
    getter line : Int32

    def initialize(message, @file : String, @line : Int32)
      super(message)
    end
  end
end

module MiniSpec::Assertions

  # Assert that expression is not nil or false.
  macro assert(expression, file = __FILE__, line = __LINE__)
    raise MiniSpec::AssertionFailed.new("Failed assertion", {{file}}, {{line}}) unless {{expression}}
  end

  # Assert that actual and expected values are equal.
  macro assert_equal(actual, expected, file = __FILE__, line = __LINE__)
    %actual = {{actual}}
    %expected = {{expected}}
    %msg = "got #{ %actual.inspect } instead of #{ %expected.inspect }"
    raise MiniSpec::AssertionFailed.new(%msg, {{file}}, {{line}}) unless %actual == %expected
  end

  # Assert that the block raises an expected exception.
  macro assert_raise(expected = Exception, file = __FILE__, line = __LINE__)
    begin
      {{yield}}
    rescue %exception : {{expected}}
      # Passed
    rescue %exception
      %msg = "got #{%exception.inspect} instead of #{{{expected}}.inspect}"
      raise MiniSpec::AssertionFailed.new(%msg, {{file}}, {{line}})
    else
      %msg = "Expected #{{{expected}}.class.name} to be raised"
      raise MiniSpec::AssertionFailed.new(%msg, {{file}}, {{line}})
    end
  end

end
