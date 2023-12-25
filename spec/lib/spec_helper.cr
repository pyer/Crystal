
require "spec"
require "file_utils"

def datapath(*components)
  File.join("test", "data", *components)
end

