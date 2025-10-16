class Logger

  # A logging severity level.
  enum Level
    Trace
    Debug
    Info
    Warn
    Error
    None
  end

  @level = Level::Info

  def initialize(level = Level::Info)
    @level = level
  end

  def trace(message)
    puts "[TRACE] #{message}" if @level <= Level::Trace
  end

  def debug(message)
    puts "[DEBUG] #{message}" if @level <= Level::Debug
  end

  def info(message)
    puts "[INFO ] #{message}" if @level <= Level::Info
  end

  def warn(message)
    puts "[WARN ] #{message}" if @level <= Level::Warn
  end

  def error(message)
    puts "[ERROR] #{message}" if @level <= Level::Error
  end

end

