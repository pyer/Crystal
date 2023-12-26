require "colorize"

module Mtest
  class Reporter
    getter :count, :results, :start_time, :total_time, :failures, :errors, :skips

    def initialize
      @results = [] of Result
      @count = 0
      @failures = 0
      @errors = 0
      @skips = 0
      @total_time = Time::Span.zero
      @start_time = Time.monotonic
      puts "Test"
    end

    def record(result : Result) : Nil
      @count += 1
      if !result.passed? || result.skipped?
        results << result
      end

      if result.passed?
        print result.result_code.colorize(:green)
      elsif result.skipped?
        print result.result_code.colorize(:yellow)
      else
        print Colorize::Object.new(result.result_code).back(:red)
      end
    rescue ex
      puts ex
    end

    def report : Nil
      @total_time = Time.monotonic - start_time
      @failures = results.count(&.failure.is_a?(Assertion))
      @errors = results.count(&.failure.is_a?(UnexpectedError))
      @skips = results.count(&.failure.is_a?(Skip))
      puts

      results.each_with_index do |result, i|
        loc = "#{result.class_name}##{result.name}"

        result.failures.each do |exception|
          case exception
          when Assertion
            puts "  #{i + 1}) Failure: #{loc}".colorize(:red)
          when UnexpectedError
            puts "  #{i + 1}) Error: #{loc}".colorize(:red)
          when Skip
            puts "  #{i + 1}) Skipped: #{loc}".colorize(:yellow)
          else
            # shut up, crystal (you're wrong)
          end
        end
      end

      puts
      puts "#{count} tests, #{failures} failures, #{errors} errors, #{skips} skips"
      puts "Elapsed time : #{total_time}"
    end
  end
end
