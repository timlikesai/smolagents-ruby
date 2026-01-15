require_relative "models/health"
require_relative "models/reliability"
require_relative "models/queue"

module Smolagents
  module Concerns
    # Model behavior concerns for LLM adapters.
    #
    # This module re-exports model-specific concerns for easy access.
    # Each concern can be included independently or composed together.
    #
    # @example Building a resilient model
    #   class MyModel
    #     include Concerns::Models::ModelHealth
    #     include Concerns::Models::ModelReliability
    #   end
    #
    # @see ModelHealth For health checks and discovery
    # @see ModelReliability For failover and retry
    # @see RequestQueue For serialized execution
    module Models
    end
  end
end
