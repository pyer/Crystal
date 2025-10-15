require "./routes"

class Router
  include HTTP::Handler
  include Routes
  @routes = Hash(String, Proc(String)).new

  def initialize
    routes
  end

  # @routes is a hash where key=method:path
  # the value is the content of the response sent to the client
  def get(path : String, &block : -> String)
    # to do : replace puts by log
    # puts "  get " + path
    # filling the hash
    @routes["GET "+path] = block
  end

  def call(context : HTTP::Server::Context)
    begin
      key = context.request.method+" "+context.request.path
      text = @routes[key].call
      context.response.reset
      context.response.content_type = _find_mime(key)
      context.response.puts(text)
    rescue KeyError
      call_next(context)
    end
  end

  # default mime types
  DEFAULT_MIME_TYPE = "text/html"
  STREAM_MIME_TYPE  = "application/octet-stream"

  # get a mime from file extension
  MIME_TYPE = {
    "html" =>  "text/html",
    "css"  =>  "text/css",
    "gif"  =>  "image/gif",
    "jpeg" =>  "image/jpeg",
    "jpg"  =>  "image/jpeg",
    "png"  =>  "image/png",
    "ico"  =>  "image/vnd.microsoft.icon",
    "js"   =>  "application/javascript",
    "json" =>  "application/json"
  }

  def _find_mime(req : String)
    dot = req.rindex('.')
    return DEFAULT_MIME_TYPE if dot.nil?
    len = req.size
    ext = req[dot+1, len]
    mime = MIME_TYPE[ext]
    mime = STREAM_MIME_TYPE if mime.nil?
    return mime
  end

end

