module System
  # Prints directly to stderr without going through an IO.
  # This is useful for error messages from components that are required for
  # IO to work (fibers, scheduler, event_loop).
  def self.print_error(message, *args)
    LibC.dprintf 2, message, *args
  end

  def self.print_exception(message, ex)
    print_error "%s: %s (%s)\n", message, ex.message || "(no message)", ex.class.name
    begin
      if bt = ex.backtrace?
        bt.each do |frame|
          print_error "  from %s\n", frame
        end
      else
        print_error "  (no backtrace)\n"
      end
    rescue ex
      print_error "Error while trying to dump the backtrace: %s (%s)\n", ex.message || "(no message)", ex.class.name
    end
  end
end
