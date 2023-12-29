require "c/netdb"
require "time"
#require "time/span"

# On musl systems, librt is empty. The entire library is already included in libc.
# On gnu systems, it's been integrated into `glibc` since 2.34 and it's not available
# as a shared library.
{% if flag?(:linux) && flag?(:gnu) && !flag?(:interpreted) && !flag?(:android) %}
  @[Link("rt")]
{% end %}

@[Link("event")]
lib LibEvent2
  alias Int = LibC::Int

  alias EvutilSocketT = Int

  type EventBase = Void*
  type Event = Void*

  @[Flags]
  enum EventLoopFlags
    Once     = 0x01
    NonBlock = 0x02
  end

  @[Flags]
  enum EventFlags : LibC::Short
    Timeout = 0x01
    Read    = 0x02
    Write   = 0x04
    Signal  = 0x08
    Persist = 0x10
    ET      = 0x20
  end

  alias Callback = (EvutilSocketT, EventFlags, Void*) ->

  fun event_get_version : UInt8*
  fun event_base_new : EventBase
  fun event_base_dispatch(eb : EventBase) : Int
  fun event_base_loop(eb : EventBase, flags : EventLoopFlags) : Int
  fun event_base_loopbreak(eb : EventBase) : Int
  fun event_set_log_callback(callback : (Int, UInt8*) -> Nil)
  fun event_enable_debug_mode
  fun event_reinit(eb : EventBase) : Int
  fun event_new(eb : EventBase, s : EvutilSocketT, events : EventFlags, callback : Callback, data : Void*) : Event
  fun event_free(event : Event)
  fun event_add(event : Event, timeout : LibC::Timeval*) : Int
  fun event_del(event : Event) : Int

  type DnsBase = Void*
  type DnsGetAddrinfoRequest = Void*

  EVUTIL_EAI_CANCEL = -90001

  alias DnsGetAddrinfoCallback = (Int32, LibC::Addrinfo*, Void*) ->

  fun evdns_base_new(base : EventBase, init : Int32) : DnsBase
  fun evdns_base_free(base : DnsBase, fail_requests : Int32)
  fun evdns_getaddrinfo(base : DnsBase, nodename : UInt8*, servname : UInt8*, hints : LibC::Addrinfo*, cb : DnsGetAddrinfoCallback, arg : Void*) : DnsGetAddrinfoRequest
  fun evdns_getaddrinfo_cancel(DnsGetAddrinfoRequest)
  fun evutil_freeaddrinfo(ai : LibC::Addrinfo*)

  {% if flag?(:preview_mt) %}
    fun evthread_use_pthreads : Int
  {% end %}
end

{% if flag?(:preview_mt) %}
  LibEvent2.evthread_use_pthreads
{% end %}

# :nodoc:
module System::LibEvent
  struct Event
    include System::EventLoop::Event

    VERSION = String.new(LibEvent2.event_get_version)

    def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
      block
    end

    def initialize(@event : LibEvent2::Event)
      @freed = false
    end

    def add(timeout : ::Time::Span?) : Nil
      if timeout
        timeval = LibC::Timeval.new(
          tv_sec: LibC::TimeT.new(timeout.total_seconds),
          tv_usec: timeout.nanoseconds // 1_000
        )
        LibEvent2.event_add(@event, pointerof(timeval))
      else
        LibEvent2.event_add(@event, nil)
      end
    end

    def free : Nil
      LibEvent2.event_free(@event) unless @freed
      @freed = true
    end

    def delete
      unless LibEvent2.event_del(@event) == 0
        raise "Error deleting event"
      end
    end

    # :nodoc:
    struct Base
      def initialize
        @base = LibEvent2.event_base_new
      end

      def reinit : Nil
        unless LibEvent2.event_reinit(@base) == 0
          raise "Error reinitializing libevent"
        end
      end

      def new_event(s : Int32, flags : LibEvent2::EventFlags, data, &callback : LibEvent2::Callback)
        event = LibEvent2.event_new(@base, s, flags, callback, data.as(Void*))
        System::LibEvent::Event.new(event)
      end

      def run_loop : Nil
        LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::None)
      end

      def run_once : Nil
        LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::Once)
      end

      def loop_break : Nil
        LibEvent2.event_base_loopbreak(@base)
      end

      def new_dns_base(init = true)
        DnsBase.new LibEvent2.evdns_base_new(@base, init ? 1 : 0)
      end
    end

    struct DnsBase
      def initialize(@dns_base : LibEvent2::DnsBase)
      end

      def getaddrinfo(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
        request = LibEvent2.evdns_getaddrinfo(@dns_base, nodename, servname, hints, callback, data.as(Void*))
        GetAddrInfoRequest.new request if request
      end

      struct GetAddrInfoRequest
        def initialize(@request : LibEvent2::DnsGetAddrinfoRequest)
        end

        def cancel
          LibEvent2.evdns_getaddrinfo_cancel(@request)
        end
      end
    end
  end
end
