require_relative "parallel_agents/errors"
require_relative "parallel_agents/combinators"
require_relative "parallel_agents/execution"

module Smolagents
  module Concerns
    module Orchestration
      # Parallel sub-agent execution with result aggregation.
      #
      # ParallelAgents enables spawning multiple sub-agents concurrently
      # with various completion strategies (all, race, any).
      #
      # @example Spawn parallel agents
      #   results = spawn_parallel([
      #     { persona: :researcher, task: "Find papers on X" },
      #     { persona: :analyst, task: "Analyze market trends" }
      #   ])
      #
      # @example Race - first to complete wins
      #   result = spawn_race([
      #     { agent: fast_agent, task: "Quick search" },
      #     { agent: thorough_agent, task: "Deep search" }
      #   ])
      #
      # @see Executors::AgentFuture For individual agent futures
      module ParallelAgents
        def self.included(base)
          base.include(Combinators)
          base.include(Execution)
        end
      end
    end
  end
end
