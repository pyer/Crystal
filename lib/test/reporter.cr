require "colorize"
require "mutex"

module Minitest
  class AbstractReporter

    def initialize
      @mutex = Mutex.new
    end

    def start : Nil
    end

    def record(result : Result) : Nil
    end

    def report : Nil
    end

    def pause : Nil
      @mutex.lock
    end

    def resume : Nil
      @mutex.unlock
    end
  end

  class CompositeReporter < AbstractReporter
    getter reporters

    def initialize
      @reporters = [] of AbstractReporter
      super
    end

    def <<(reporter : AbstractReporter)
      reporters << reporter
    end

    def start : Nil
      puts "Testing ..."
      reporters.each(&.start)
    end

    def record(result : Result) : Nil
      reporters.each(&.record(result))
    end

    def report : Nil
      reporters.each(&.report)
    end

    def pause : Nil
      reporters.each(&.pause)
    end

    def resume : Nil
      reporters.each(&.resume)
    end
  end

  class ProgressReporter < AbstractReporter
    def record(result : Result) : Nil
      @mutex.lock

      if result.passed?
        print result.result_code.colorize(:green)
      elsif result.skipped?
        print result.result_code.colorize(:yellow)
      else
        print Colorize::Object.new(result.result_code).back(:red)
      end
    rescue ex
      puts ex
      puts ex.backtrace.join("\n")
    ensure
      @mutex.unlock
    end
  end

  class SummaryReporter < AbstractReporter
    getter :count, :results, :start_time, :total_time, :failures, :errors, :skips

    def initialize
      super

      @results = [] of Minitest::Result
      @count = 0
      @failures = 0
      @errors = 0
      @skips = 0
      @start_time = uninitialized Time::Span # avoid nilable
      @total_time = uninitialized Time::Span # avoid nilable
    end

    def start : Nil
      @start_time = Time.monotonic
    end

    def record(result) : Nil
      @mutex.synchronize do
        @count += 1

        if !result.passed? || result.skipped?
          results << result
        end
      end
    end

    def report : Nil
      super
      @total_time = Time.monotonic - start_time
      @failures = results.count(&.failure.is_a?(Assertion))
      @errors = results.count(&.failure.is_a?(UnexpectedError))
      @skips = results.count(&.failure.is_a?(Skip))

      puts
      puts "\nElapsed time : #{total_time}"

      results.each_with_index do |result, i|
        loc = "#{result.class_name}##{result.name}"

        result.failures.each do |exception|
          case exception
          when Assertion
            puts "  #{i + 1}) Failure:".colorize(:red)
            puts "#{loc} [#{exception.__minitest_location}]:\n#{exception.message}"
          when UnexpectedError
            puts "  #{i + 1}) Error:".colorize(:red)
            puts "#{loc} [#{exception.__minitest_location}]:\n#{exception.message}"
            puts "    #{exception.backtrace.join("\n    ")}"
          when Skip
            puts "  #{i + 1}) Skipped:".colorize(:yellow)
            puts "#{loc} [#{exception.__minitest_location}]:\n#{exception.message}"
          else
            # shut up, crystal (you're wrong)
          end
          puts
        end
      end

      puts "#{count} tests, #{failures} failures, #{errors} errors, #{skips} skips"
    end
  end
end
