
module MiniSpec::DSL

  class Context
    @@before = -> () { }
    @@after  = -> () { }

    def self.add_before(&block)
      @@before = block
    end

    def self.add_after(&block)
      @@after = block
    end

    def self.setup
      proc = @@before.not_nil!
      proc.call
    end

    def self.teardown
      proc = @@after.not_nil!
      proc.call
    end

  end

  macro before(file = __FILE__, line = __LINE__, &block)
    Context.add_before do
      {{ block.body }}
    end
  end

  macro after(file = __FILE__, line = __LINE__, &block)
    Context.add_after do
      {{ block.body }}
    end
  end

  macro test(name, file = __FILE__, line = __LINE__, &block)
    Context.setup

    begin
      {{ yield }}
      MiniSpec::PassedTest.new {{name}}, {{file}}, {{line}}
    rescue
      MiniSpec::FailedTest.new {{name}}, {{file}}, {{line}}
    end

    Context.teardown
  end

  macro pending(name, file = __FILE__, line = __LINE__)
    MiniSpec::PendingTest.new({{name}}, {{file}}, {{line}})
  end

  macro pending(name, file = __FILE__, line = __LINE__, &block)
    MiniSpec::PendingTest.new({{name}}, {{file}}, {{line}})
  end

end

