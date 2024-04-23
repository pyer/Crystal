
require "./tinytest/assertions"
require "./tinytest/hooks"
require "./tinytest/exceptions"
require "./tinytest/result"

#     for name in @type.methods.map(&.name).select(&.starts_with?("test_"))
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
    rescue ex : Tinytest::Assertion | Tinytest::Skip
      result.failures << ex
    rescue ex : Exception
      result.failures << Tinytest::UnexpectedError.new(ex)
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

