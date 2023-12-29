
# :nodoc:
abstract class System::EventLoop
  # Creates an event loop instance
  def self.create : System::EventLoop
    System::LibEvent::EventLoop.new
  end

  # Runs the event loop.
  abstract def run_once : Nil

  # Create a new resume event for a fiber.
  abstract def create_resume_event(fiber : Fiber) : Event

  # Creates a timeout_event.
  abstract def create_timeout_event(fiber : Fiber) : Event

  module Event
    # Frees the event.
    abstract def free : Nil

    # Adds a new timeout to this event.
    abstract def add(timeout : Time::Span?) : Nil
  end
end

require "./event_libevent"

# :nodoc:
class System::LibEvent::EventLoop < System::EventLoop
  private getter(event_base) { System::LibEvent::Event::Base.new }

  {% unless flag?(:preview_mt) %}
    # Reinitializes the event loop after a fork.
    def after_fork : Nil
      event_base.reinit
    end
  {% end %}

  # Runs the event loop.
  def run_once : Nil
    event_base.run_once
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : System::EventLoop::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      Scheduler.enqueue data.as(Fiber)
    end
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : System::EventLoop::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      f = data.as(Fiber)
      if (select_action = f.timeout_select_action)
        f.timeout_select_action = nil
        select_action.time_expired(f)
      else
        Scheduler.enqueue f
      end
    end
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : System::EventLoop::Event
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Write)
        io_ref.resume_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_write(timed_out: true)
      end
    end
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : System::EventLoop::Event
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Read)
        io_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_read(timed_out: true)
      end
    end
  end
end
