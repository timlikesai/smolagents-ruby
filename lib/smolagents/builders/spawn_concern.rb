module Smolagents
  module Builders
    # Spawn configuration DSL methods for AgentBuilder.
    #
    # Allows agents to spawn child agents with constrained capabilities.
    # Enforces privilege restriction to prevent escalation attacks.
    module SpawnConcern
      # Configure agent's ability to spawn child agents.
      #
      # @param allow [Array<Symbol>] Model roles children can use (empty = any registered)
      # @param tools [Array<Symbol>] Tools available to children (default: [:final_answer])
      # @param inherit [Symbol] Context inheritance (:task_only, :observations, :summary, :full)
      # @param max_children [Integer] Maximum spawned agents (default: 3)
      # @param max_depth [Integer] Maximum spawn nesting depth (default: 2)
      # @param max_steps [Integer] Maximum steps per spawned agent (default: 10)
      # @return [AgentBuilder]
      #
      # @example Configure spawn capability
      #   builder = Smolagents.agent.can_spawn(allow: [:researcher], tools: [:search])
      #   builder.config[:spawn_config].nil?
      #   #=> false
      #
      # @example Spawn with observation inheritance
      #   builder = Smolagents.agent.can_spawn(inherit: :observations, max_children: 5)
      #   builder.config[:spawn_config].max_children
      #   #=> 5
      #
      # @example Spawn with depth and step limits
      #   builder = Smolagents.agent.can_spawn(
      #     max_depth: 2,
      #     allowed_tools: [:search],
      #     max_steps: 5
      #   )
      #   builder.config[:spawn_policy].max_depth
      #   #=> 2
      def can_spawn(
        allow: [], tools: [:final_answer], inherit: :task_only, max_children: 3,
        max_depth: 2, max_steps: 10, allowed_tools: nil
      )
        check_frozen!

        spawn_config = Types::SpawnConfig.create(allow:, tools:, inherit:, max_children:)
        spawn_policy = Security::SpawnPolicy.create(
          max_depth:,
          allowed_tools: allowed_tools || tools,
          max_steps_per_agent: max_steps,
          inherit_restrictions: true
        )
        with_config(spawn_config:, spawn_policy:)
      end
    end
  end
end
