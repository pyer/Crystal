# minispec

A minimalist test framework for Crystal.


## Example

```crystal
require "minispec"

before do
  # to be executed before each test
end

after do
  # to be executed after each test
end

test "true assertion" do
  assert true
end

test "equality" do
  assert_equal 1.to_s, "1"
end

test "exception" do
  assert_raise Exception do
    raise Exception.new("Boom!")
  end
end

pending "to do" do
  # work in progress
end
```


## Usage

```crystal
require "minispec"
```

Run your tests with `crystal spec`.

### Tests

- `test`
- `pending`

### Assertions

- `assert`
- `assert_equal`
- `assert_raise`

### Before/After blocks

If you need to run code _before_ or _after_ each test, declare each block like in the example below.

```crystal
before do
  # First block to be executed
end

after do
  # Third and last block to be executed
end

test "executes the before, test and after blocks" do
    # Second block to be executed
end
```

