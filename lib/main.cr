
lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

module Main

  # :nodoc:
  def self.exit(status : Int32, exception : Exception?) : Int32
    status = Kernel::AtExitHandlers.run status, exception

    if exception
      STDERR.print "Unhandled exception: "
      exception.inspect_with_backtrace(STDERR)
    end

    ignore_stdio_errors { STDOUT.flush }
    ignore_stdio_errors { STDERR.flush }

    status
  end

  # :nodoc:
  def self.ignore_stdio_errors(&)
    yield
  rescue IO::Error
  end

  # Main method run by all Crystal programs at startup.
  #
  # This setups up the GC, invokes your program, rescuing
  # any handled exception, and then runs `at_exit` handlers.
  #
  # This method is automatically invoked for you, so you
  # don't need to invoke it.
  #
  def self.main(argc : Int32, argv : UInt8**)
    GC.init
    LibCrystalMain.__crystal_main(argc, argv)
    exit(0)
  rescue ex
    exit(1, ex)
  end

end

# Main function that acts as C's main function.
fun main(argc : Int32, argv : UInt8**) : Int32
  Main.main(argc, argv)
end

