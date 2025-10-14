require "../src/minispec"

class DummyException < Exception
end

test "assert succeeds if the value is true" do
      assert true
end

test "assert raises if the assertion fails" do
      assert_raise(MiniSpec::AssertionFailed) { assert false }
end

test "assert_equal succeeds if both arguments are equal" do
      assert_equal 1, 1
end

test "assert_equal raises if both arguments are different" do
      assert_raise(MiniSpec::AssertionFailed) { assert_equal 1, 0 }
end


test "should pass if the code block raises an exception of any kind" do
      assert_raise { raise "Boom!" }
end

test "should pass if the code block raises that exception" do
      assert_raise(DummyException) { raise DummyException.new }
end

test "should fail if the code block does not raise any exceptions" do
      assert_raise(MiniSpec::AssertionFailed) { assert_raise { } }
end

test "should fail if the code block raises an exception different than the one it was specified" do
      assert_raise(MiniSpec::AssertionFailed) {
          assert_raise(DummyException) do
            raise Exception.new
          end
      }
end

