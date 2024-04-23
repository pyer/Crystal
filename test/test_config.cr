require "tinytest"

class Test

  def test_version
    assert_equal "2.0.0", Crystal::VERSION
  end

  def test_llvm_version
    assert_equal "17.0.6", Crystal::LLVM_VERSION
  end

  def test_target
    assert_equal "x86_64-linux-gnu", Crystal::TARGET_TRIPLE
  end

end

