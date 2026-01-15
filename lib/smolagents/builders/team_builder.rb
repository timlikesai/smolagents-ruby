module Smolagents
  module Builders
    # Chainable builder for multi-agent teams.
    #
    # @example Team with coordinator
    #   Smolagents.team
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .agent(Smolagents.agent(:code).tools(:search), as: "researcher")
    #     .agent(Smolagents.agent(:code).tools(:write_file), as: "writer")
    #     .coordinate("Coordinate: research, then write")
    #     .build
    TeamBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers

      define_handler :agent, maps_to: :agent_complete

      def self.default_configuration
        { agents: {}, model_block: nil, coordinator_instructions: nil, coordinator_type: :code,
          max_steps: nil, planning_interval: nil, handlers: [] }
      end

      # @return [TeamBuilder]
      def self.create = new(configuration: default_configuration)

      register_method :agent, description: "Add team member", required: true
      register_method :max_steps, description: "Set max coordinator steps (1-1000)",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }
      register_method :coordinate, description: "Set coordination instructions",
                                   validates: ->(v) { v.is_a?(String) && !v.empty? }

      # Set shared model for coordinator.
      # @yield Block returning a Model instance
      # @return [TeamBuilder]
      def model(&block) = with_config(model_block: block)

      # Add an agent to the team.
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for team member
      # @return [TeamBuilder]
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end

      # Set coordination instructions.
      # @param instructions [String] How to coordinate sub-agents
      # @return [TeamBuilder]
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end

      # Set coordinator agent type.
      # @param type [Symbol] :code or :tool
      # @return [TeamBuilder]
      def coordinator(type) = with_config(coordinator_type: type.to_sym)

      # @param count [Integer] Maximum steps (1-1000)
      # @return [TeamBuilder]
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # @param interval [Integer] Steps between planning
      # @return [TeamBuilder]
      def planning(interval:) = with_config(planning_interval: interval)

      # Build the team coordinator.
      # @return [Agent] Coordinator with managed sub-agents
      def build
        validate_config!
        coordinator = build_coordinator(resolve_model, resolve_agent_class)
        register_handlers(coordinator)
        coordinator
      end

      def config = configuration.dup

      def inspect
        agent_names = configuration[:agents].keys.join(", ")
        "#<TeamBuilder agents=[#{agent_names}] coordinator=#{configuration[:coordinator_type]}>"
      end

      private

      def resolve_agent_class = Object.const_get(Builders::AGENT_TYPES.fetch(configuration[:coordinator_type]))

      def build_managed_agents = configuration[:agents].map { |name, agent| ManagedAgentTool.new(agent:, name:) }

      def build_coordinator(model, agent_class)
        cfg = configuration
        agent_class.new(
          model:, tools: [], managed_agents: build_managed_agents,
          custom_instructions: cfg[:coordinator_instructions],
          max_steps: cfg[:max_steps], planning_interval: cfg[:planning_interval]
        )
      end

      def register_handlers(coordinator)
        configuration[:handlers].each { |event_type, block| coordinator.on(event_type, &block) }
      end

      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
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
