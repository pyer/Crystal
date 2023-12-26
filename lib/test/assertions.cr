require "./diff"

lib LibC
  fun dup(Int) : Int
end

module Mtest
  # Decorator for the original exception.
  class UnexpectedError < Exception
  end

  class Assertion < Exception
  end

  class Skip < Exception
  end

  module Assertions
    def diff(expected : String, actual : String) : String
      diff = Diff.line_diff(expected, actual)

      String.build do |str|
        str << "--- expected\n"
        str << "+++ actual\n"

        diff.each do |delta|
          case delta.type
          when .unchanged?
            delta.a.each { |i| str << ' ' << diff.a[i] << '\n' }
          when .appended?
            delta.b.each { |i| str << '+' << diff.b[i] << '\n' }
          when .deleted?
            delta.a.each { |i| str << '-' << diff.a[i] << '\n' }
          end
        end
      end.chomp
    end

    def diff(expected, actual) : String
      left = expected.pretty_inspect.gsub("\\n", '\n') unless expected.is_a?(String)
      right = actual.pretty_inspect.gsub("\\n", '\n') unless actual.is_a?(String)
      diff(left, right)
    end

    def assert(actual, message = nil) : Bool
      return true if actual

      msg =
        case message
        when String
          message
        when Proc
          message.call
        else
          "failed assertion"
        end

      raise Mtest::Assertion.new(msg)
    end

    def assert(message = nil, &) : Bool
      assert yield, message
    end

    def refute(actual, message = nil) : Bool
      assert !actual, message || "failed refutation"
    end

    def refute(message = nil, &) : Bool
      refute yield, message
    end

    def assert_equal(expected, actual, message = nil) : Bool
      msg = self.message(message) do
        if need_diff?(expected, actual)
          result = diff(expected, actual)
          if result.empty?
            "No visual difference found. Maybe expected class '#{expected.class.name}' isn't comparable to actual class '#{actual.class.name}' ?"
          else
            result
          end
        else
          "Expected #{expected.inspect} but got #{actual.inspect}"
        end
      end
      assert expected == actual, msg
    end

    def refute_equal(expected, actual, message = nil) : Bool
      msg = self.message(message) { "Expected #{expected.inspect} to not be equal to #{actual.inspect}" }
      assert expected != actual, msg
    end

    def assert_same(expected, actual, message = nil) : Bool
      msg = self.message(message) {
        "Expected #{actual.inspect} (oid=#{actual.object_id}) to be the same as #{expected.inspect} (oid=#{expected.object_id})"
      }
      if expected.responds_to?(:same?)
        assert expected.same?(actual), msg
      else
        assert_responds_to expected, :same?, nil
      end
    end

    def refute_same(expected, actual, message = nil) : Bool
      msg = self.message(message) {
        "Expected #{actual.inspect} (oid=#{actual.object_id}) to not be the same as #{expected.inspect} (oid=#{expected.object_id})"
      }
      if expected.responds_to?(:same?)
        refute expected.same?(actual), msg
      else
        assert_responds_to expected, :same?, nil
      end
    end

    def assert_match(pattern : Regex, actual, message = nil) : Bool
      msg = self.message(message) { "Expected #{pattern.inspect} to match: #{actual.inspect}" }
      assert actual =~ pattern, msg
    end

    def assert_match(pattern, actual, message = nil) : Bool
      msg = self.message(message) { "Expected #{pattern.inspect} to match #{actual.inspect}" }
      assert actual =~ Regex.new(Regex.escape(pattern.to_s)), msg
    end

    def refute_match(pattern : Regex, actual, message = nil) : Bool
      msg = self.message(message) { "Expected #{pattern.inspect} to not match #{actual.inspect}" }
      refute actual =~ pattern, msg
    end

    def refute_match(pattern, actual, message = nil) : Bool
      msg = self.message(message) { "Expected #{pattern.inspect} to not match #{actual.inspect}" }
      refute actual =~ Regex.new(Regex.escape(pattern.to_s)), msg
    end

    def assert_empty(actual, message = nil) : Bool
      if actual.responds_to?(:empty?)
        msg = self.message(message) { "Expected #{actual.inspect} to be empty" }
        assert actual.empty?, msg
      else
        assert_responds_to actual, :empty?
      end
    end

    def refute_empty(actual, message = nil) : Bool
      if actual.responds_to?(:empty?)
        msg = self.message(message) { "Expected #{actual.inspect} to not be empty" }
        refute actual.empty?, msg
      else
        assert_responds_to actual, :empty?
      end
    end

    def assert_nil(actual, message = nil) : Bool
      assert_equal nil, actual, message
    end

    def refute_nil(actual, message = nil) : Bool
      refute_equal nil, actual, message
    end

    def assert_in_delta(expected : Number, actual : Number, delta : Number = 0.001, message = nil) : Bool
      n = (expected.to_f - actual.to_f).abs
      msg = self.message(message) { "Expected #{expected} - #{actual} (#{n}) to be <= #{delta}" }
      assert delta >= n, msg
    end

    def refute_in_delta(expected : Number, actual : Number, delta : Number = 0.001, message = nil) : Bool
      n = (expected.to_f - actual.to_f).abs
      msg = self.message(message) { "Expected #{expected} - #{actual} (#{n}) to not be <= #{delta}" }
      refute delta >= n, msg
    end

    def assert_in_epsilon(a : Number, b : Number, epsilon : Number = 0.001, message = nil) : Bool
      delta = [a.to_f.abs, b.to_f.abs].min * epsilon
      assert_in_delta a, b, delta, message
    end

    def refute_in_epsilon(a : Number, b : Number, epsilon : Number = 0.001, message = nil) : Bool
      delta = a.to_f * epsilon
      refute_in_delta a, b, delta, message
    end

    def assert_includes(collection, obj, message = nil) : Bool
      msg = self.message(message) { "Expected #{collection.inspect} to include #{obj.inspect}" }
      if collection.responds_to?(:includes?)
        assert collection.includes?(obj), msg
      else
        assert_responds_to collection, :includes?
      end
    end

    def refute_includes(collection, obj, message = nil) : Bool
      msg = self.message(message) { "Expected #{collection.inspect} to not include #{obj.inspect}" }
      if collection.responds_to?(:includes?)
        refute collection.includes?(obj), msg
      else
        assert_responds_to collection, :includes?
      end
    end

    def assert_instance_of(cls, obj, message = nil) : Bool
      msg = self.message(message) do
        "Expected #{obj.inspect} to be an instance of #{cls.name}, not #{obj.class.name}"
      end
      assert cls === obj, msg
    end

    def refute_instance_of(cls, obj, message = nil) : Bool
      msg = self.message(message) do
        "Expected #{obj.inspect} to not be an instance of #{cls.name}"
      end
      refute cls === obj, msg
    end

    macro assert_responds_to(obj, method, message = nil)
      %msg = self.message({{ message }}) do
        "Expected #{ {{ obj }}.inspect} (#{ {{ obj }}.class.name}) to respond to ##{ {{ method }} }"
      end
      assert {{ obj }}.responds_to?(:{{ method.id }}), %msg
    end

    macro refute_responds_to(obj, method, message = nil)
      %msg = self.message({{ message }}) do
        "Expected #{ {{ obj }}.inspect} (#{ {{ obj }}.class.name}) to not respond to ##{ {{ method }} }"
      end
      refute {{ obj }}.responds_to?(:{{ method.id }}), %msg
    end

    def assert_raises(message : String? = nil, &) : Exception
      yield
    rescue ex
      ex
    else
      message ||= "Expected an exception but nothing was raised"
      raise Assertion.new(message)
    end

    def assert_raises(klass : T.class, &) : T forall T
      yield
    rescue ex : T
      ex
    rescue ex
      message = "Expected #{T.name} but #{ex.class.name} was raised"
      raise Assertion.new(message)
    else
      message = "Expected #{T.name} but nothing was raised"
      raise Assertion.new(message)
    end

    def assert_silent(&) : Bool
      assert_output("", "") do
        yield
      end
    end

    def assert_output(stdout = nil, stderr = nil, &) : Bool
      output, error = capture_io { yield }

      o = stdout.is_a?(Regex) ? assert_match(stdout, output) : assert_equal(stdout, output) if stdout
      e = stderr.is_a?(Regex) ? assert_match(stderr, error) : assert_equal(stderr, error) if stderr

      (!stdout || !!o) && (!stderr || !!e)
    end

    def capture_io(& : ->) : {String, String}
      File.tempfile("out") do |stdout|
        File.tempfile("err") do |stderr|
          reopen(STDOUT, stdout) do
            reopen(STDERR, stderr) do
              yield
            end
          end
          return {
            stdout.rewind.gets_to_end,
            stderr.rewind.gets_to_end,
          }
        ensure
          stderr.delete
        end
      ensure
        stdout.delete
      end
      raise "unreachable"
    end

    private def reopen(src, dst, & : ->) : Nil
      if (backup_fd = LibC.dup(src.fd)) == -1
        raise IO::Error.from_errno("dup")
      end

      begin
        src.reopen(dst)
        yield
        src.flush
      ensure
        if LibC.dup2(backup_fd, src.fd) == -1
          raise IO::Error.from_errno("dup")
        end
        LibC.close(backup_fd)
      end
    end

    def skip(message = "") : NoReturn
      raise Mtest::Skip.new(message.to_s)
    end

    def flunk(message = "Epic Fail!") : NoReturn
      raise Mtest::Assertion.new(message.to_s)
    end

    def message(message : Nil, &block : -> String) : -> String
      block
    end

    def message(message : String, &block : -> String) : -> String
      if message.blank?
        block
      else
        ->{ "#{message}\n#{block.call}" }
      end
    end

    def message(message : Proc(String), &block : -> String) : -> String
      ->{ "#{message.call}\n#{block.call}" }
    end

    private def need_diff?(expected, actual) : Bool
      need_diff?(expected.inspect) &&
        need_diff?(actual.inspect)
    end

    private def need_diff?(obj : String) : Bool
      !!obj.index("") && obj.size > 30
    end
  end
end
