require_relative "collections/agent_memory"
require_relative "collections/tool_stats_aggregator"
require_relative "collections/action_step_builder"

module Smolagents
  module Collections
    # Mutable collection classes for runtime state management.
    #
    # This module contains mutable classes that accumulate state during agent
    # execution. These are intentionally separated from the immutable Data.define
    # types in the Types module.
    #
    # @see AgentMemory Accumulates conversation history
    # @see ToolStatsAggregator Tracks tool usage statistics
    # @see ActionStepBuilder Builds immutable ActionStep instances
  end
end
