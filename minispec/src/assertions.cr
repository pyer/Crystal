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
  macro assert(expression, msg = nil, file = __FILE__, line = __LINE__)
    %evaluation = {{expression}}

    unless %evaluation
      %msg = {{msg}} || "Failed assertion"

      raise MiniSpec::AssertionFailed.new(%msg, {{file}}, {{line}})
    end

    MiniSpec.increment(:assertions)
  end

  # Assert that actual and expected values are equal.
  macro assert_equal(actual, expected, msg = nil, file = __FILE__, line = __LINE__)
    %actual = {{actual}}
    %expected = {{expected}}

    %msg = {{msg}} || "got #{ %actual.inspect } instead of #{ %expected.inspect }"

    assert(%actual == %expected, %msg, {{file}}, {{line}})
  end

  # Assert that the block raises an expected exception.
  macro assert_raise(expected = Exception, msg = nil, file = __FILE__, line = __LINE__)
    begin
      {{yield}}
    rescue %exception : {{expected}}
      MiniSpec.increment(:assertions)
    rescue %exception
      %ex = %exception.is_a?({{expected}})
      assert(%ex, "got #{%ex.inspect} instead of #{{{expected}}.inspect}", {{file}}, {{line}})
    else
      %msg = {{msg}} || "Expected #{{{expected}}.class.name} to be raised"
      raise MiniSpec::AssertionFailed.new(%msg, {{file}}, {{line}})
    end
  end

end
