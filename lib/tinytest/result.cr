require "colorize"

module Tinytest
  class Result
    getter message : String
    getter status  : String
    getter color   : Symbol
    property! time : Time::Span

    def initialize(name : String)
      @message = "  - " + name + " : "
      @status = "OK"
      @color = :green
    end

    def assert(st : String)
      @status = st
      @color  = :red
    end

    def skip(st : String)
      @status = st.empty? ? "skipped" : st
      @color  = :yellow
    end

    def error(st : String)
      @status = st
      @color  = :red
    end

    def report
      print @message
      puts @status.colorize(@color)
    end

  end
end

