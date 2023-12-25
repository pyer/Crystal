require "spec"

def datapath(*components)
  File.join("test", "data", *components)
end

