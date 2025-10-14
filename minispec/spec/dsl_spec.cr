require "../src/minispec"

flag = false
tag = false

before do
  flag = true
end

after do
  flag = false
  tag = true
end

test "DSL test 'before'" do
  assert flag
  assert !tag
end

test "DSL test 'after'" do
  assert flag
  assert tag
end


n_passed  = MiniSpec.passed
n_pending = MiniSpec.pending + 2

pending "DSL test 'pending' alone"

pending "DSL test 'pending' with block" do
    # Exception is ignored
    raise Exception
end

test "DSL pending" do
  assert_equal MiniSpec.passed,  n_passed
  assert_equal MiniSpec.pending, n_pending
end

