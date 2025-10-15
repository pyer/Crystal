require "minispec"
require "../src/routes"

class Mock
  @@count = 0

  def self.increment
    @@count += 1
  end

  def self.count
    @@count
  end
end

include Routes

# Mock function 'get'
def get(path : String, &block : -> String)
  Mock.increment
end

test "number of routes" do
  routes
  assert_equal Mock.count, 8
end

