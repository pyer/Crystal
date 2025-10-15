require "minispec"
require "http/server"
require "../src/router"

test "default mime type" do
  assert_equal Router::DEFAULT_MIME_TYPE,  "text/html"
end

test "stream mime type" do
  assert_equal Router::STREAM_MIME_TYPE, "application/octet-stream"
end

test "find default mime type" do
  router = Router.new
  mime = router._find_mime("/url/path")
  assert_equal mime, "text/html"
end

test "find text mime type" do
  router = Router.new
  mime = router._find_mime("/url/iindex.html")
  assert_equal mime, "text/html"
end

