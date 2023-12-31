require "c/pthread"

class Thread
  class Mutex
    # Creates a new mutex.
    def initialize
      attributes = uninitialized LibC::PthreadMutexattrT
      LibC.pthread_mutexattr_init(pointerof(attributes))
      LibC.pthread_mutexattr_settype(pointerof(attributes), LibC::PTHREAD_MUTEX_ERRORCHECK)

      ret = LibC.pthread_mutex_init(out @mutex, pointerof(attributes))
      raise RuntimeError.from_os_error("pthread_mutex_init", Errno.new(ret)) unless ret == 0

      LibC.pthread_mutexattr_destroy(pointerof(attributes))
    end

    # Locks the mutex from the current thread.
    def lock : Nil
      ret = LibC.pthread_mutex_lock(self)
      raise RuntimeError.from_os_error("pthread_mutex_lock", Errno.new(ret)) unless ret == 0
    end

    # Tries to lock the mutex and returns `false` if failed.
    def try_lock : Bool
      case ret = Errno.new(LibC.pthread_mutex_trylock(self))
      when .none?
        true
      when Errno::EBUSY
        false
      else
        raise RuntimeError.from_os_error("pthread_mutex_trylock", ret)
      end
    end

    # Unlocks the mutex from the current thread.
    def unlock : Nil
      ret = LibC.pthread_mutex_unlock(self)
      raise RuntimeError.from_os_error("pthread_mutex_unlock", Errno.new(ret)) unless ret == 0
    end

    # Locks the mutex, yields to the block and ensures it unlocks afterwards.
    def synchronize(&)
      lock
      yield self
    ensure
      unlock
    end

    def finalize
      ret = LibC.pthread_mutex_destroy(self)
      raise RuntimeError.from_os_error("pthread_mutex_destroy", Errno.new(ret)) unless ret == 0
    end

    def to_unsafe
      pointerof(@mutex)
    end
  end
end
