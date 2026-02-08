# Bootstrap file for live experiments
# Loads the full smolagents library and experiment infrastructure

# Load .env before infrastructure (which uses ENV.fetch with defaults)
env_file = File.expand_path("../.env", __dir__)
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    ENV[key.strip] = value.strip if key && value
  end
end

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))

# Load the full library
require "smolagents"

# Load experiment infrastructure
require_relative "infrastructure"
