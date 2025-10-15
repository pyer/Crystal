require "minispec"
require "../src/version"

test "version" do
  assert_equal VERSION, "1.2"
end
