require "tinytest"

class Test

  def test_build_version
    assert_equal "2.0.1", Crystal::VERSION
  end

  def test_llvm_version
    assert_equal "17.0.6", Crystal::LLVM_VERSION
  end

end

