
require "./tinytest/assertions"
require "./tinytest/hooks"
require "./tinytest/exceptions"
require "./tinytest/result"

class Test
    include Tinytest::Assertions
    include Tinytest::Hooks

    macro methods
      tests =[] of {Test.class, String, Proc(Test, Nil)}
      {% for name in @type.methods.map(&.name).select(&.starts_with?("test_")) %}
          %proc = ->(test : Test) {
            test.as({{ @type }}).{{ name }}
            nil
          }
          tests << { {{ @type }}, {{ name.stringify }}, %proc }
      {% end %}
    end

    def capture_exception(result : Tinytest::Result, &) : Nil
      yield
    rescue ex : Tinytest::Assertion
      result.assert(ex.message.to_s)
    rescue ex : Tinytest::Skip
      result.skip(ex.message.to_s)
    rescue ex : Exception
      result.error(ex.message.to_s)
    end

    def run
      #puts Test.methods.shuffle
      Test.methods.shuffle.each do | test |
        suite, name, proc = test
        result = Tinytest::Result.new(name) 

        capture_exception(result) do
          before_setup
          setup
          after_setup
          proc.call(self)
        end

        capture_exception(result) { before_teardown }
        capture_exception(result) { teardown }
        capture_exception(result) { after_teardown }

        result.report
      end
    end
end

Test.new.run

