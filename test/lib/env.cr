require "test"

class EnvTest < Minitest::Test

  def test_non_existent_env
    assert_raises(KeyError) do
      ENV["NON-EXISTENT"]
    end
    assert ENV["NON-EXISTENT"]?.nil?
  end

  def test_set_and_get_env
    # set env
    ENV["FOO"] = "1"
    assert_equal("1", ENV["FOO"])
    # test case sensitive
    assert ENV["foo"]?.nil?
    # delete env
    ENV.delete("FOO")
    assert ENV["FOO"]?.nil?
    refute ENV.has_key?("FOO")
    # set to nil (same as delete)
    ENV["FOO"] = "2"
    assert_equal("2", ENV["FOO"])
    ENV["FOO"] = nil
    assert ENV["FOO"]?.nil?
    refute ENV.has_key?("FOO")
  end

  def test_empty_string
    ENV["FOO"] = ""
    assert_equal("", ENV["FOO"])
    assert_empty(ENV["FOO"])
    ENV.delete("FOO")
    refute ENV.has_key?("FOO")
  end

  def test_has_key
    ENV["FOO"] = "3"
    assert ENV.has_key?("FOO")
    ENV.delete("FOO")
    refute ENV.has_key?("FOO")

    assert ENV.has_key?("HOME")
    refute ENV.has_key?("NON_EXISTENT")
  end

  def test_env_keys
    keys = [ "FOO", "BAR"]
    keys.each { |k|
      refute ENV.keys.includes?(k)
    }
    ENV["FOO"] = ENV["BAR"] = "1"
    keys.each { |k|
      assert ENV.keys.includes?(k)
    }
    keys.each { |k|
      ENV.delete(k)
    }
  end

  def test_no_empty_key
    # Setting an empty key is invalid on both POSIX and Windows. So reporting an empty key
    # would always be a bug. And there *was* a bug - see win32/ Crystal::System::Env.each
    refute ENV.keys.includes?("")
  end

  def test_env_values
    [1, 2].each { |i|
      refute ENV.values.includes?("SOMEVALUE_#{i}")
    }
    ENV["FOO"] = "SOMEVALUE_1"
    ENV["BAR"] = "SOMEVALUE_2"
    [1, 2].each { |i|
      assert ENV.values.includes?("SOMEVALUE_#{i}")
    }
    ENV.delete("FOO")
    ENV.delete("BAR")
  end

  def test_nul_byte_in_key
    assert_raises(ArgumentError) do
      ENV["FOO\0BAR"] = "something"
    end
    assert_raises(ArgumentError) do
      ENV["FOO\0BAR"] = nil
    end
  end

  def test_nul_byte_in_value
    assert_raises(ArgumentError) do
      ENV["FOO"] = "BAR\0BAZ"
    end
  end

  def test_env_fetch
    ENV["1"] = "2"
    assert_equal("2", ENV.fetch("1"))
    # with default value
    assert_equal("2", ENV.fetch("1", "3"))
    assert_equal("3", ENV.fetch("2", "3"))
    # with block
    assert_equal("2", ENV.fetch("1") { |k| k + "block" })
    assert_equal("2block", ENV.fetch("2") { |k| k + "block" })
    assert_equal(4, ENV.fetch("3") { 4 })
    assert_raises(KeyError) do
      ENV.fetch("2")
    end
    ENV.delete("1")
  end

  def test_unicode_values
    ENV["TEST_UNICODE_1"] = "bar\u{d7ff}\u{10000}"
    assert_equal("bar\u{d7ff}\u{10000}", ENV["TEST_UNICODE_1"])
    ENV["TEST_UNICODE_2"] = "\u{1234}"
    assert_equal("\u{1234}", ENV["TEST_UNICODE_2"])

    values = {} of String => String
    ENV.each do |key, value|
      if key.starts_with?("TEST_UNICODE_")
        values[key] = value
      end
    end

    assert_equal({
      "TEST_UNICODE_1" => "bar\u{d7ff}\u{10000}",
      "TEST_UNICODE_2" => "\u{1234}",
    }, values)
    ENV.delete("TEST_UNICODE_1")
    ENV.delete("TEST_UNICODE_2")
  end

  def test_env_to_h
    ENV["FOO"] = "foo"
    assert_equal("foo", ENV.to_h["FOO"])
    ENV.delete("FOO")
  end

end
