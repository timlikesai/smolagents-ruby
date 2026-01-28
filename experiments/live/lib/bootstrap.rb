# Bootstrap file for live experiments
# Loads the full smolagents library and experiment infrastructure

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))

# Load the full library
require "smolagents"

# Load experiment infrastructure
require_relative "infrastructure"
