require "test"
require "system/group"

class SystemGroupTest < Test

  GROUP_NAME         = {{ `id -gn`.stringify.chomp }}
  GROUP_ID           = {{ `id -g`.stringify.chomp }}
  INVALID_GROUP_NAME = "this_group_does_not_exist"
  INVALID_GROUP_ID   = "123456789"

  def test_group_by_name
    group = System::Group.find_by(name: GROUP_NAME)
    assert group.is_a?(System::Group)
    assert_equal(GROUP_NAME, group.name)
    assert_equal(GROUP_ID, group.id)
  end

  def test_nonexistent_group_by_name
    assert_raises(System::Group::NotFoundError) do
      group = System::Group.find_by(name: INVALID_GROUP_NAME)
    end
  end

  def test_group_by_id
    group = System::Group.find_by(id: GROUP_ID)
    assert group.is_a?(System::Group)
    assert_equal(GROUP_NAME, group.name)
    assert_equal(GROUP_ID, group.id)
  end

  def test_nonexistent_group_by_id
    assert_raises(System::Group::NotFoundError) do
      group = System::Group.find_by(id: INVALID_GROUP_ID)
    end
  end

  def test_query_group_by_name
    group = System::Group.find_by?(name: GROUP_NAME)
    refute group.nil?
    assert group.is_a?(System::Group)
    assert_equal(GROUP_NAME, group.name) unless group.nil?
    assert_equal(GROUP_ID, group.id)     unless group.nil?
  end

  def test_query_nonexistent_group_by_name
    group = System::Group.find_by?(name: INVALID_GROUP_NAME)
    assert group.nil?
  end

  def test_query_group_by_id
    group = System::Group.find_by?(id: GROUP_ID)
    refute group.nil?
    assert group.is_a?(System::Group)
    assert_equal(GROUP_NAME, group.name) unless group.nil?
    assert_equal(GROUP_ID, group.id)     unless group.nil?
  end

  def test_query_nonexistent_group_by_id
    group = System::Group.find_by?(id: INVALID_GROUP_ID)
    assert group.nil?
  end

  def test_group_to_string
    group = System::Group.find_by(name: GROUP_NAME)
    assert_equal("#{GROUP_NAME} (#{GROUP_ID})", group.to_s)
  end

end
