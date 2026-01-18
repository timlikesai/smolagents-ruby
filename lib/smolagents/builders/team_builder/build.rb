module Smolagents
  module Builders
    # Build logic for TeamBuilder.
    #
    # Handles building the coordinator agent with all configured sub-agents,
    # model resolution, and configuration validation.
    module TeamBuilderBuild
      # Build the team coordinator with all configured sub-agents.
      #
      # Creates a coordinator agent that has access to all sub-agents as
      # managed agents. The coordinator can delegate tasks to sub-agents.
      #
      # @return [Agent] Coordinator agent with managed sub-agents
      # @raise [ArgumentError] If no agents have been added
      #
      # @example Building the team
      #   team = Smolagents.team
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .agent(Smolagents.agent.tools(:search), as: "researcher")
      #     .coordinate("Research and summarize")
      #     .build
      #   team.class.name
      #   #=> "Smolagents::Agents::Agent"
      def build
        validate_config!
        coordinator = build_coordinator(resolve_model, resolve_agent_class)
        register_handlers(coordinator)
        coordinator
      end

      private

      def resolve_agent_class
        Object.const_get(Builders::AGENT_TYPES.fetch(configuration[:coordinator_type]))
      end

      def build_managed_agents
        configuration[:agents].map { |name, agent| ManagedAgentTool.new(agent:, name:) }
      end

      def build_coordinator(model, agent_class)
        agent_class.new(
          model:,
          tools: [],
          managed_agents: build_managed_agents,
          config: build_coordinator_config
        )
      end

      def build_coordinator_config
        cfg = configuration
        Types::AgentConfig.create(
          custom_instructions: cfg[:coordinator_instructions],
          max_steps: cfg[:max_steps],
          planning_interval: cfg[:planning_interval]
        )
      end

      def register_handlers(coordinator)
        configuration[:handlers].each { |event_type, block| coordinator.on(event_type, &block) }
      end

      def resolve_model
        if configuration[:model_block]
          configuration[:model_block].call
        elsif configuration[:agents].any?
          configuration[:agents].values.first.model
        else
          raise ArgumentError, "Model required. Use .model { } or add agents with models"
        end
      end

      def validate_config!
        return unless configuration[:agents].empty?

        raise ArgumentError, "At least one agent required. Use .agent(agent, as: 'name')"
      end
    end
  end
end
