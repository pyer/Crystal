require "c/grp"

# Represents a group of users on the host system.
#
# NOTE: To use Group, you must explicitly import it with `require "system/group"`
#
# Groups can be retrieved by either group name or their group ID:
#
# ```
# require "system/group"
#
# System::Group.find_by name: "staff"
# System::Group.find_by id: "0"
# ```
class System::Group
  private GETGR_R_SIZE_MAX = 1024 * 16

  # Raised on group lookup failure.
  class NotFoundError < Exception
  end

  # The group's name.
  getter name : String

  # The group's identifier.
  getter id : String

  def_equals_and_hash @id

  private def initialize(@name, @id)
  end

  # Returns the group associated with the given name.
  #
  # Raises `NotFoundError` if no such group exists.
  def self.find_by(*, name : String) : System::Group
    find_by?(name: name) || raise NotFoundError.new("No such group: #{name}")
  end

  # Returns the group associated with the given name.
  #
  # Returns `nil` if no such group exists.
  def self.find_by?(*, name : String) : System::Group?
    name.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    System.retry_with_buffer("getgrnam_r", GETGR_R_SIZE_MAX) do |buf|
      LibC.getgrnam_r(name, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    from_struct(grp) if grp_pointer
  end

  # Returns the group associated with the given ID.
  #
  # Raises `NotFoundError` if no such group exists.
  def self.find_by(*, id : String) : System::Group
    find_by?(id: id) || raise NotFoundError.new("No such group: #{id}")
  end

  # Returns the group associated with the given ID.
  #
  # Returns `nil` if no such group exists.
  def self.find_by?(*, id : String) : System::Group?
    groupid = id.to_u32?
    return unless groupid

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    System.retry_with_buffer("getgrgid_r", GETGR_R_SIZE_MAX) do |buf|
      LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end
    from_struct(grp) if grp_pointer
  end

  def to_s(io)
    io << name << " (" << id << ')'
  end

  private def self.from_struct(grp)
    new(String.new(grp.gr_name), grp.gr_gid.to_s)
  end

end
