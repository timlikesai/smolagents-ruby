require_relative "agents/react_loop"
require_relative "agents/planning"
require_relative "agents/managed"
require_relative "agents/async"
require_relative "agents/specialized"

module Smolagents
  module Concerns
    # Agent behavior concerns for building intelligent agents.
    #
    # This module re-exports agent-specific concerns for easy access.
    # Each concern can be included independently or composed together.
    #
    # @example Building a code agent
    #   class MyAgent
    #     include Concerns::Agents::ReActLoop
    #     include Concerns::Agents::Planning
    #   end
    #
    # @see ReActLoop For the main agent execution loop
    # @see Planning For agent planning and replanning
    # @see ManagedAgents For sub-agent management
    # @see AsyncTools For async tool support
    # @see Specialized For agent DSL definitions
    module Agents
    end
  end
end
