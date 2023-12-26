
require "test/assertions"
require "test/reporter"
require "test/result"
require "test/runnable"

class Test < Mtest::Runnable
    include Mtest::Assertions

    def setup
    end

    def teardown
    end

    def run_one(name : String, reporter : Mtest::Reporter, proc : Test ->) : Nil
      result = Mtest::Result.new(self.class.name, name)

      result.time = Time.measure do
        capture_exception(result) do
          setup
          proc.call(self)
        end
        capture_exception(result) do
          teardown
        end
      end

      reporter.record(result)
    end

    def capture_exception(result : Mtest::Result, &) : Nil
      yield
    rescue ex : Mtest::Assertion | Mtest::Skip
      result.failures << ex
    rescue ex : Exception
      result.failures << Mtest::UnexpectedError.new(ex.message)
    end

end

def run_test
    seed   = Random.rand(0_u32..0xFFFF_u32)
    random = Random::PCG32.new(seed.to_u64)
    reporter = Mtest::Reporter.new

    # shuffle each suite, then shuffle tests for each suite:
    Mtest::Runnable.runnables.shuffle!(random).each do |suite|
        suite
          .collect_tests
          .shuffle!(random)
          .each { |test|
            suite, name, proc = test
            suite.new().run_one(name, reporter, proc)
          }
    end
    reporter.report
end

run_test
