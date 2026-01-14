# Loader for Smolagents custom RuboCop cops
# These cops enforce our event-driven architecture

require_relative "smolagents/no_sleep"
require_relative "smolagents/no_timing_assertion"
require_relative "smolagents/no_timeout_block"
