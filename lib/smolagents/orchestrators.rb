# Orchestrators for multi-agent coordination.
#
# The Orchestrators module contains orchestration patterns for coordinating
# execution across multiple agents. Currently provides Ractor-based parallel
# orchestration for true concurrency without GVM lock constraints.
#
# == Available Orchestrators
#
# - {RactorOrchestrator} - Coordinate agents in parallel using Ractor
#
# == Design
#
# Orchestrators manage:
# - Agent spawning and lifecycle
# - Task distribution and scheduling
# - Result collection and merging
# - Error handling across agent boundaries
# - Resource limits and cleanup
#
# == Use Cases
#
# - Parallel agent teams executing independent tasks
# - Fan-out/fan-in patterns (split work, merge results)
# - Structured concurrency with proper cleanup
#
# @example Using RactorOrchestrator
#   orchestrator = Smolagents::Orchestrators::RactorOrchestrator.new
#   agents = [agent1, agent2, agent3]
#   tasks = ["task 1", "task 2", "task 3"]
#   results = orchestrator.execute(agents, tasks)
#
# @see Orchestrators::RactorOrchestrator For Ractor-based parallel execution
module Smolagents
  module Orchestrators
  end
end

require_relative "orchestrators/ractor_orchestrator"
