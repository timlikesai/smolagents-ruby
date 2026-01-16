require_relative "runtime/agent_memory"
require_relative "runtime/tool_stats_aggregator"
require_relative "runtime/action_step_builder"
require_relative "runtime/environment"
require_relative "runtime/spawn"

module Smolagents
  # Mutable runtime state classes for agent execution.
  #
  # This module contains mutable classes that accumulate state during agent
  # execution. These are intentionally separated from the immutable Data.define
  # types in the Types module.
  #
  # @example Using AgentMemory
  #   memory = Smolagents::Runtime::AgentMemory.new("You are a helpful assistant.")
  #   memory.add_task("Calculate 2+2")
  #   memory.to_messages.size >= 2  #=> true
  #
  # @example Using ToolStatsAggregator
  #   stats = Smolagents::Runtime::ToolStatsAggregator.new
  #   stats.record("search", duration: 0.5, error: false)
  #   stats["search"].call_count  #=> 1
  #
  # @see AgentMemory Conversation history and step tracking
  # @see ToolStatsAggregator Tool usage statistics
  # @see ActionStepBuilder Mutable builder for action steps
  module Runtime
  end
end
