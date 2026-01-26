module Smolagents
  module Builders
    module TeamResolutionConcern
      private

      def resolve_agent_class = Object.const_get(Builders::AGENT_CLASS)

      def build_managed_agents = configuration[:agents].map { |name, agent| ManagedAgentTool.new(agent:, name:) }

      def build_coordinator(model, agent_class)
        cfg = configuration
        agent_config = Types::AgentConfig.create(
          max_steps: cfg[:max_steps],
          planning: build_planning_config(cfg),
          behavioral: build_behavioral_config(cfg)
        )
        agent_class.new(
          model:, tools: [], managed_agents: build_managed_agents, config: agent_config
        )
      end

      def build_planning_config(cfg)
        return nil if cfg[:planning_interval].nil?

        Types::PlanningConfig.create(interval: cfg[:planning_interval])
      end

      def build_behavioral_config(cfg)
        return nil if cfg[:coordinator_instructions].nil?

        Types::BehavioralConfig.create(custom_instructions: cfg[:coordinator_instructions])
      end

      def register_handlers(coordinator)
        configuration[:handlers].each { |event_type, block| coordinator.on(event_type, &block) }
      end

      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
      end

      def field_to_config_key(name)
        { agent: :agents }[name] || name
      end

      def resolve_agent(agent_or_builder)
        case agent_or_builder
        when AgentBuilder
          if agent_or_builder.config[:model_block].nil? && configuration[:model_block]
            agent_or_builder = agent_or_builder.model(&configuration[:model_block])
          end
          agent_or_builder.build
        else
          agent_or_builder
        end
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

        raise ArgumentError,
              "At least one agent required. Use .agent(agent, as: 'name')"
      end
    end
  end
end
