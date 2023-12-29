
require "c/pthread"
require "c/sched"
require "thread/thread_linked_list"

# :nodoc:
class Thread
  # Creates and starts a new system thread.
  # def initialize(&proc : ->)

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  # def initialize

  # Suspends the current thread until this thread terminates.
  # def join : Nil

  # Returns the Fiber representing the thread's main stack.
  # def main_fiber

  # Yields the thread.
  # def self.yield : Nil

  # Returns the Thread object associated to the running system thread.
  # def self.current : Thread

  # Associates the Thread object to the running system thread.
  # def self.current=(thread : Thread)

  # Holds the GC thread handler
  property gc_thread_handler : Void* = Pointer(Void).null

  class ConditionVariable
    # Creates a new condition variable.
    def initialize
      attributes = uninitialized LibC::PthreadCondattrT
      LibC.pthread_condattr_init(pointerof(attributes))

      {% unless flag?(:darwin) %}
        LibC.pthread_condattr_setclock(pointerof(attributes), LibC::CLOCK_MONOTONIC)
      {% end %}

      ret = LibC.pthread_cond_init(out @cond, pointerof(attributes))
      raise RuntimeError.from_os_error("pthread_cond_init", Errno.new(ret)) unless ret == 0

      LibC.pthread_condattr_destroy(pointerof(attributes))
    end

    # Unblocks one thread that is waiting on `self`.
    def signal : Nil
      ret = LibC.pthread_cond_signal(self)
      raise RuntimeError.from_os_error("pthread_cond_signal", Errno.new(ret)) unless ret == 0
    end

    # Unblocks all threads that are waiting on `self`.
    def broadcast : Nil
      ret = LibC.pthread_cond_broadcast(self)
      raise RuntimeError.from_os_error("pthread_cond_broadcast", Errno.new(ret)) unless ret == 0
    end

    # Causes the calling thread to wait on `self` and unlock the given *mutex* atomically.
    def wait(mutex : Thread::Mutex) : Nil
      ret = LibC.pthread_cond_wait(self, mutex)
      raise RuntimeError.from_os_error("pthread_cond_wait", Errno.new(ret)) unless ret == 0
    end

    # Causes the calling thread to wait on `self` and unlock the given *mutex* atomically
    # within the given *time* span. Yields to the given block if a timeout occurs.
    def wait(mutex : Thread::Mutex, time : Time::Span, & : ->)
      ret =
        {% if flag?(:darwin) %}
          ts = uninitialized LibC::Timespec
          ts.tv_sec = time.to_i
          ts.tv_nsec = time.nanoseconds

          LibC.pthread_cond_timedwait_relative_np(self, mutex, pointerof(ts))
        {% else %}
          LibC.clock_gettime(LibC::CLOCK_MONOTONIC, out ts)
          ts.tv_sec += time.to_i
          ts.tv_nsec += time.nanoseconds

          if ts.tv_nsec >= 1_000_000_000
            ts.tv_sec += 1
            ts.tv_nsec -= 1_000_000_000
          end

          LibC.pthread_cond_timedwait(self, mutex, pointerof(ts))
        {% end %}

      case errno = Errno.new(ret)
      when .none?
        # normal resume from #signal or #broadcast
      when Errno::ETIMEDOUT
        yield
      else
        raise RuntimeError.from_os_error("pthread_cond_timedwait", errno)
      end
    end

    def finalize
      ret = LibC.pthread_cond_destroy(self)
      raise RuntimeError.from_os_error("pthread_cond_broadcast", Errno.new(ret)) unless ret == 0
    end

    def to_unsafe
      pointerof(@cond)
    end
  end

  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  protected class_getter(threads) { Thread::LinkedList(Thread).new }

  @th : LibC::PthreadT
  @exception : Exception?
  @detached = Atomic(UInt8).new(0)
  @main_fiber : Fiber?

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  def self.unsafe_each(&)
    threads.unsafe_each { |thread| yield thread }
  end

  # Starts a new system thread.
  def initialize(&@func : ->)
    @th = uninitialized LibC::PthreadT

    ret = GC.pthread_create(pointerof(@th), Pointer(LibC::PthreadAttrT).null, ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))

    if ret != 0
      raise RuntimeError.from_os_error("pthread_create", Errno.new(ret))
    end
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @func = ->{}
    @th = LibC.pthread_self
    @main_fiber = Fiber.new(stack_address, self)

    Thread.threads.push(self)
  end

  private def detach(&)
    if @detached.compare_and_set(0, 1).last
      yield
    end
  end

  # Suspends the current thread until this thread terminates.
  def join : Nil
    detach { GC.pthread_join(@th) }

    if exception = @exception
      raise exception
    end
  end

  @[ThreadLocal]
  @@current : Thread?

  # Returns the Thread object associated to the running system thread.
  def self.current : Thread
    # Thread#start sets @@current as soon it starts. Thus we know
    # that if @@current is not set then we are in the main thread
    @@current ||= new
  end

  # Associates the Thread object to the running system thread.
  protected def self.current=(@@current : Thread) : Thread
  end

  def self.yield : Nil
    ret = LibC.sched_yield
    raise RuntimeError.from_errno("sched_yield") unless ret == 0
  end

  # Returns the Fiber representing the thread's main stack.
  def main_fiber : Fiber
    @main_fiber.not_nil!
  end

  # :nodoc:
  def scheduler : Scheduler
    @scheduler ||= Scheduler.new(main_fiber)
  end

  protected def start
    Thread.threads.push(self)
    Thread.current = self
    @main_fiber = fiber = Fiber.new(stack_address, self)

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      Thread.threads.delete(self)
      Fiber.inactive(fiber)
      detach { GC.pthread_detach(@th) }
    end
  end

  private def stack_address : Void*
    address = Pointer(Void).null

      if LibC.pthread_getattr_np(@th, out attr) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise RuntimeError.from_os_error("pthread_attr_destroy", Errno.new(ret)) unless ret == 0

    address
  end

  # :nodoc:
  def to_unsafe
    @th
  end
end

# In musl (alpine) the calls to unwind API segfaults
# when the binary is statically linked. This is because
# some symbols like `pthread_once` are defined as "weak"
# and, for some reason, not linked into the final binary.
# Adding an explicit reference to the symbol ensures it's
# included in the statically linked binary.
{% if flag?(:musl) && flag?(:static) %}
  lib LibC
    fun pthread_once(Void*, Void*)
  end

  fun __crystal_static_musl_workaround
    LibC.pthread_once(nil, nil)
  end
{% end %}

