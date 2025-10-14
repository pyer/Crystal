module MiniSpec

  @@tests = [] of Test
  @@counter = {
    :assertions => 0,
    :passed     => 0,
    :pending    => 0,
    :failures   => 0,
  }
  @@tag = {
    :assertions => "",
    :passed     => ".",
    :pending    => "P",
    :failures   => "F",
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
    @@counter[:failures]
  end

  def self.report
    report = @@counter.map { |k, v| "#{v} #{k}" }
    puts "\n", report.join(", ")

    @@tests.each &.description
  end

  def self.store(test : Test)
    @@tests.push test
  end

  abstract class Test
    def initialize(@name : String, @file : String, @line : Int32)
      MiniSpec.increment(@id)
      MiniSpec.store(self)
    end

    def description
      raise "subclass responsibility"
    end
  end

  class PassedTest < Test
    @id = :passed

    def description
      # Do nothing
      #puts "Passed : #{@name}"
    end
  end

  class PendingTest < Test
    @id = :pending

    def description
      puts "Pending : #{@name}"
    end
  end

  class FailedTest < Test
    @id = :failures

    def description
      bn = Path[@file].basename
      puts "Failed : #{@name} [#{bn}:#{@line}]"
    end
  end

end
