
require "test/assertions"
require "test/reporter"
require "test/result"
require "test/runnable"

module Minitest

  class Test < Runnable
    include Assertions

    def setup
    end

    def teardown
    end

    def run_one(name : String, proc : Test ->) : Nil
      result = Result.new(self.class.name, name)

      result.time = Time.measure do
        capture_exception(result) do
          setup
          proc.call(self)
        end

        capture_exception(result) { teardown }
      end

      __reporter.record(result)
    end

    def capture_exception(result : Result, &) : Nil
      yield
    rescue ex : Assertion | Skip
      result.failures << ex
    rescue ex : Exception
      result.failures << UnexpectedError.new(ex)
    end

    @@failures = [] of Assertion | Skip | UnexpectedError

    def self.failures : Array(Assertion, Skip, UnexpectedError)
      @@failures
    end
  end

  def self.run : Nil
    reporter = CompositeReporter.new
    reporter << ProgressReporter.new
    reporter << SummaryReporter.new
    seed   = Random.rand(0_u32..0xFFFF_u32)
    random = Random::PCG32.new(seed.to_u64)

    reporter.start
    # shuffle each suite, then shuffle tests for each suite:
    Runnable.runnables.shuffle!(random).each do |suite|
        suite
          .collect_tests
          .shuffle!(random)
          .each { |test|
            suite, name, proc = test
            suite.new(reporter).run_one(name, proc)
          }
    end
    reporter.report
  end
end

Minitest.run

