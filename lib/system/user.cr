require "c/pwd"

# Represents a user on the host system.
#
# NOTE: To use User, you must explicitly import it with `require "system/user"`
#
# Users can be retrieved by either username or their user ID:
#
# ```
# require "system/user"
#
# System::User.find_by name: "root"
# System::User.find_by id: "0"
# ```
class System::User
  GETPW_R_SIZE_MAX = 1024 * 16

  # Raised on user lookup failure.
  class NotFoundError < Exception
  end

  # The user's username.
  getter username : String

  # The user's identifier.
  getter id : String

  # The user's primary group identifier.
  getter group_id : String

  # The user's real or full name.
  #
  # May not be present on all platforms. Returns the same value as `#username`
  # if neither a real nor full name is available.
  getter name : String

  # The user's home directory.
  getter home_directory : String

  # The user's login shell.
  getter shell : String

  def_equals_and_hash @id

  private def initialize(@username, @id, @group_id, @name, @home_directory, @shell)
  end

  # Returns the home directory of the current user
  #
  # Raises `RuntimeError` if the directory does not exist.
  def self.home : String
    if home_path = ENV["HOME"]?.presence
      home_path
    else
      id = LibC.getuid

      pwd = uninitialized LibC::Passwd
      pwd_pointer = pointerof(pwd)
      ret = nil
      System.retry_with_buffer("getpwuid_r", User::GETPW_R_SIZE_MAX) do |buf|
        ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
      end

      if pwd_pointer
        String.new(pwd.pw_dir)
      else
        raise RuntimeError.from_os_error("getpwuid_r", Errno.new(ret.not_nil!))
      end
    end
  end

  # Returns the user associated with the given username.
  #
  # Raises `NotFoundError` if no such user exists.
  def self.find_by(*, name : String) : System::User
    find_by?(name: name) || raise NotFoundError.new("No such user: #{name}")
  end

  # Returns the user associated with the given username.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, name : String) : System::User?
    name.check_no_null_byte
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwnam_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwnam_r(name, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end
    from_struct(pwd) if pwd_pointer
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFoundError` if no such user exists.
  def self.find_by(*, id : String) : System::User
    find_by?(id: id) || raise NotFoundError.new("No such user: #{id}")
  end

  # Returns the user associated with the given ID.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, id : String) : System::User?
    id = id.to_u32?
    return unless id

    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    from_struct(pwd) if pwd_pointer
  end

  def to_s(io)
    io << username << " (" << id << ')'
  end

  private def self.from_struct(pwd)
    username = String.new(pwd.pw_name)
    # `pw_gecos` is not part of POSIX and bionic for example always leaves it null
    user = pwd.pw_gecos ? String.new(pwd.pw_gecos).partition(',')[0] : username
    new(username, pwd.pw_uid.to_s, pwd.pw_gid.to_s, user, String.new(pwd.pw_dir), String.new(pwd.pw_shell))
  end

end
