require "c/unistd"

module System
  # Returns the hostname.
  #
  # NOTE: Maximum of 253 characters are allowed, with 2 bytes reserved for
  # storage.
  # In practice, many platforms will disallow anything longer than 63 characters.
  #
  # ```
  # System.hostname # => "host.example.org"
  # ```
  def self.hostname : String
    String.new(255) do |buffer|
      unless LibC.gethostname(buffer, LibC::SizeT.new(255)) == 0
        raise RuntimeError.from_errno("Could not get hostname")
      end
      len = LibC.strlen(buffer)
      {len, len}
    end
  end

  # Returns the number of logical processors available to the system.
  #
  # ```
  # System.cpu_count # => 4
  # ```
  def self.cpu_count : Int
    LibC.sysconf(LibC::SC_NPROCESSORS_ONLN)
  end

# :nodoc:
  def self.retry_with_buffer(function_name, max_buffer, &)
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf

    while (ret = yield buf.to_slice) != 0
      case ret
      when LibC::ENOENT, LibC::ESRCH, LibC::EBADF, LibC::EPERM
        return nil
      when LibC::ERANGE
        raise RuntimeError.from_errno(function_name) if buf.size >= max_buffer
        buf = Bytes.new(buf.size * 2)
      else
        raise RuntimeError.from_errno(function_name)
      end
    end
  end
end
