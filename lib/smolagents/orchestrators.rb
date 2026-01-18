# Orchestrators for multi-agent coordination.
#
# The Orchestrators module contains orchestration patterns for coordinating
# execution across multiple agents. Provides thread-based parallel
# execution where each agent's generated code is sandboxed via Ractors.
#
# == Available Orchestrators
#
# - {AgentPool} - Run agents in parallel using threads
#
# == Design
#
# Orchestrators manage:
# - Agent spawning and lifecycle
# - Task distribution and scheduling
# - Result collection and aggregation
# - Error handling across agent boundaries
# - Concurrency limits
#
# Code sandboxing (Ractor isolation) is handled by each agent's executor,
# not by the orchestrator. The orchestrator provides parallelism via threads.
#
# == Use Cases
#
# - Parallel agent teams executing independent tasks
# - Fan-out/fan-in patterns (split work, merge results)
# - Batch processing with concurrency limits
#
# @example Using AgentPool
#   pool = Smolagents::Orchestrators::AgentPool.new(
#     agents: { "researcher" => researcher, "analyst" => analyst },
#     max_concurrent: 4
#   )
#
#   result = pool.execute_parallel(tasks: [
#     ["researcher", "Find info about Ruby"],
#     ["analyst", "Analyze the findings"]
#   ])
#
#   result.all_succeeded?  #=> true
#   result.successes.map(&:output)  #=> ["...", "..."]
#
# @see Orchestrators::AgentPool For thread-based parallel execution
module Smolagents
  module Orchestrators
  end
end

require_relative "orchestrators/agent_pool"
require_relative "orchestrators/ralph_loop"
