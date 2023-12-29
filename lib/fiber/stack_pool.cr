require "c/sys/mman"

class Fiber
  # :nodoc:
  class StackPool
    STACK_SIZE = 8 * 1024 * 1024

    def initialize
      @deque = Deque(Void*).new
      @mutex = Thread::Mutex.new
    end

    # Removes and frees at most *count* stacks from the top of the pool,
    # returning memory to the operating system.
    def collect(count = lazy_size // 2) : Nil
      count.times do
        if stack = @mutex.synchronize { @deque.shift? }
          free_stack(stack, STACK_SIZE)
        else
          return
        end
      end
    end

    # Removes a stack from the bottom of the pool, or allocates a new one.
    def checkout : {Void*, Void*}
      stack = @mutex.synchronize { @deque.pop? } || allocate_stack(STACK_SIZE)
      {stack, stack + STACK_SIZE}
    end

    # Appends a stack to the bottom of the pool.
    def release(stack) : Nil
      @mutex.synchronize { @deque.push(stack) }
    end

    # Returns the approximated size of the pool. It may be equal or slightly
    # bigger or smaller than the actual size.
    def lazy_size : Int32
      @mutex.synchronize { @deque.size }
    end

    # Allocates memory for a stack.
    private def allocate_stack(stack_size) : Void*
      flags = LibC::MAP_PRIVATE | LibC::MAP_ANON
      pointer = LibC.mmap(nil, stack_size, LibC::PROT_READ | LibC::PROT_WRITE, flags, -1, 0)
      raise RuntimeError.from_errno("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED
      LibC.madvise(pointer, stack_size, LibC::MADV_NOHUGEPAGE)
      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
      pointer
    end

    # Frees memory of a stack.
    private def free_stack(stack : Void*, stack_size) : Nil
      LibC.munmap(stack, stack_size)
    end

  end
end
