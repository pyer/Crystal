require "test"
require "system/user"

class SystemUserTest < Minitest::Test

  USER_NAME         = {{ `id -un`.stringify.chomp }}
  USER_ID           = {{ `id -u`.stringify.chomp }}
  INVALID_USER_NAME = "this_user_does_not_exist"
  INVALID_USER_ID   = "123456789"

  def test_user_by_name
    user = System::User.find_by(name: USER_NAME)
    assert user.is_a?(System::User)
    assert_equal(USER_NAME, user.username)
    assert_equal(USER_ID, user.id)
  end

  def test_nonexistent_user_by_name
    assert_raises(System::User::NotFoundError) do
      user = System::User.find_by(name: INVALID_USER_NAME)
    end
  end

  def test_user_by_id
    user = System::User.find_by(id: USER_ID)
    assert user.is_a?(System::User)
    assert_equal(USER_NAME, user.username)
    assert_equal(USER_ID, user.id)
  end

  def test_nonexistent_user_by_id
    assert_raises(System::User::NotFoundError) do
      user = System::User.find_by(id: INVALID_USER_ID)
    end
  end

  def test_query_user_by_name
    user = System::User.find_by?(name: USER_NAME)
    refute user.nil?
    assert user.is_a?(System::User)
    assert_equal(USER_NAME, user.username) unless user.nil?
    assert_equal(USER_ID, user.id) unless user.nil?
  end

  def test_query_nonexistent_user_by_name
    user = System::User.find_by?(name: INVALID_USER_NAME)
    assert user.nil?
  end

  def test_query_user_by_id
    user = System::User.find_by?(id: USER_ID)
    refute user.nil?
    assert user.is_a?(System::User)
    assert_equal(USER_NAME, user.username) unless user.nil?
    assert_equal(USER_ID, user.id) unless user.nil?
  end

  def test_query_nonexistent_user_by_id
    user = System::User.find_by?(id: INVALID_USER_ID)
    assert user.nil?
  end

  def test_user_to_string
    user = System::User.find_by(name: USER_NAME)
    assert_equal("#{USER_NAME} (#{USER_ID})", user.to_s)
  end

end

