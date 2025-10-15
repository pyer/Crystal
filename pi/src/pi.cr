
require "http/server"
require "./router.cr"
require "./version.cr"

puts "PI version " + VERSION + " starting..."

# HTTP::Handler(s)
log    = HTTP::LogHandler.new
error  = HTTP::ErrorHandler.new
static = HTTP::StaticFileHandler.new(File.expand_path("."))
router = Router.new

handlers = [ log, error, router, static ]
#handlers = [ log, error, static ]

server = HTTP::Server.new(handlers)
address = server.bind_tcp 8080
puts "Listening on http://#{address}"
puts "Use Ctrl-C to stop"
server.listen

