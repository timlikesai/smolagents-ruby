module Smolagents
  module Builders
    # Spawn configuration DSL methods for AgentBuilder.
    #
    # Allows agents to spawn child agents with constrained capabilities.
    module SpawnConcern
      # Configure agent's ability to spawn child agents.
      #
      # @param allow [Array<Symbol>] Model roles children can use (empty = any registered)
      # @param tools [Array<Symbol>] Tools available to children (default: [:final_answer])
      # @param inherit [Symbol] Context inheritance (:task_only, :observations, :summary, :full)
      # @param max_children [Integer] Maximum spawned agents (default: 3)
      # @return [AgentBuilder]
      #
      # @example
      #   .can_spawn(allow: [:researcher, :fast], tools: [:search, :final_answer], inherit: :observations)
      def can_spawn(allow: [], tools: [:final_answer], inherit: :task_only, max_children: 3)
        check_frozen!

        spawn_config = Types::SpawnConfig.create(allow:, tools:, inherit:, max_children:)
        with_config(spawn_config:)
      end
    end
  end
end
