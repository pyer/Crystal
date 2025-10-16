require "minispec"
require "../src/logger"

def logs( log : Logger)
  puts
  log.trace "trace"
  log.debug "debug"
  log.info  "info"
  log.warn  "warn"
  log.error "error"
end

test "log level Trace" do
  logs Logger.new(Logger::Level::Trace)
end

test "log level Debug" do
  logs Logger.new(Logger::Level::Debug)
end

test "log level Info" do
  logs Logger.new(Logger::Level::Info)
end

test "log level Warn" do
  logs Logger.new(Logger::Level::Warn)
end

test "log level Error" do
  logs Logger.new(Logger::Level::Error)
end

test "log level None" do
  logs Logger.new(Logger::Level::None)
end

test "log default level" do
  logs Logger.new
end

