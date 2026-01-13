require_relative "collections/agent_memory"
require_relative "collections/tool_stats_aggregator"
require_relative "collections/action_step_builder"

module Smolagents
  # Mutable collection classes for runtime state management.
  #
  # This module contains mutable classes that accumulate state during agent
  # execution. These are intentionally separated from the immutable Data.define
  # types in the Types module.
  #
  # @example Using AgentMemory
  #   memory = AgentMemory.new("You are a helpful assistant.")
  #   memory.add_task("Calculate 2+2")
  #   messages = memory.to_messages
  #
  # @example Using ToolStatsAggregator
  #   stats = ToolStatsAggregator.new
  #   stats.record("search", duration: 0.5, error: false)
  #   stats["search"].call_count  # => 1
  #
  # @see AgentMemory Conversation history and step tracking
  # @see ToolStatsAggregator Tool usage statistics
  # @see ActionStepBuilder Mutable builder for action steps
  module Collections
  end
end
