# MiniSpec
require "./assertions"
require "./dsl"
require "./tests"

include MiniSpec::Assertions
include MiniSpec::DSL

at_exit do
  MiniSpec.report
  # returns the number of failed tests
  exit MiniSpec.failures
end
