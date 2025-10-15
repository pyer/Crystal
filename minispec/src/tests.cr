module MiniSpec

  @@tests = [] of Test
  @@counter = {
    :passed     => 0,
    :pending    => 0,
    :failed   => 0,
  }
  @@tag = {
    :passed     => ".",
    :pending    => "P",
    :failed   => "F",
  }

  def self.increment(key : Symbol)
    @@counter[key] += 1
    print @@tag[key]
  end

  def self.passed
    @@counter[:passed]
  end

  def self.pending
    @@counter[:pending]
  end

  def self.failures
    @@counter[:failed]
  end

  def self.print_report
    counters = @@counter.map { |k, v| "#{v} #{k}" }
    summary = counters.join(", ")
    puts "\nTests: #{summary}"
    @@tests.each &.report
  end

  def self.store(test : Test)
    @@tests.push test
  end

  abstract class Test
    def initialize(@name : String, @file : String, @line : Int32, @exception : Exception? = nil)
      MiniSpec.increment(@id)
    end

    def report
      puts description(@exception)
    end

    def description(ex : Nil)
      raise "subclass responsibility"
    end

    def description(ex : Exception)
      raise "subclass responsibility"
    end
  end

  class PassedTest < Test
    @id = :passed

    def description(ex : Nil)
      # Do nothing
      # "Passed : #{@name}"
    end
  end

  class PendingTest < Test
    @id = :pending

    def description(ex : Nil)
      "Pending : #{@name}"
    end
  end

  class FailedTest < Test
    @id = :failed

    def description(ex : Exception)
      bn = Path[@file].basename
      "Failed : #{@name} [#{bn}:#{@line}]\n\t#{ex}"
    end
  end

end
