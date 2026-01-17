module Smolagents
  module Builders
    # Chainable builder for creating multi-agent teams with a coordinator.
    #
    # TeamBuilder creates hierarchical agent teams where a coordinator agent
    # delegates tasks to specialized sub-agents. Each sub-agent can have its
    # own tools and configuration.
    #
    # == Architecture
    #
    # A team consists of:
    # - **Coordinator**: The main agent that receives tasks and delegates to sub-agents
    # - **Sub-agents**: Specialized agents that perform specific tasks
    #
    # == Model Sharing
    #
    # If sub-agents don't have a model configured, they inherit the team's model.
    # This allows sharing a single model across the team for efficiency.
    #
    # @example Creating a simple team
    #   team = Smolagents.team
    #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    #     .agent(Smolagents.agent.tools(:search), as: "researcher")
    #     .coordinate("Delegate research tasks")
    #     .build
    #   team.class.name
    #   #=> "Smolagents::Agents::Agent"
    #
    # @example Setting coordination instructions
    #   builder = Smolagents.team.coordinate("First research, then summarize findings")
    #   builder.config[:coordinator_instructions]
    #   #=> "First research, then summarize findings"
    #
    # @example Setting max steps
    #   builder = Smolagents.team.max_steps(50)
    #   builder.config[:max_steps]
    #   #=> 50
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
      register_method :max_steps, description: "Set max coordinator steps (1-#{Config::MAX_STEPS_LIMIT})",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }
      register_method :coordinate, description: "Set coordination instructions",
                                   validates: ->(v) { v.is_a?(String) && !v.empty? }

      # Set the shared model for the coordinator and sub-agents.
      #
      # The model block is evaluated lazily at build time. Sub-agents that
      # don't have their own model will inherit this one.
      #
      # @yield Block returning a Model instance
      # @return [TeamBuilder] New builder with model configured
      #
      # @example Setting team model
      #   builder = Smolagents.team.model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #   builder.config[:model_block].nil?
      #   #=> false
      def model(&block) = with_config(model_block: block)

      # Add an agent to the team.
      #
      # Agents can be added as either pre-built Agent instances or AgentBuilder
      # instances. If an AgentBuilder without a model is added, it will inherit
      # the team's model at build time.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for the team member (used for delegation)
      # @return [TeamBuilder] New builder with agent added
      #
      # @example Adding an agent with a model
      #   builder = Smolagents.team
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .agent(Smolagents.agent.tools(:search), as: "researcher")
      #   builder.config[:agents].key?("researcher")
      #   #=> true
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end

      # Set coordination instructions for the coordinator agent.
      #
      # These instructions guide how the coordinator delegates tasks to sub-agents
      # and combines their results.
      #
      # @param instructions [String] How to coordinate sub-agents
      # @return [TeamBuilder] New builder with instructions set
      #
      # @example Setting coordination strategy
      #   builder = Smolagents.team.coordinate("First research the topic, then summarize findings")
      #   builder.config[:coordinator_instructions]
      #   #=> "First research the topic, then summarize findings"
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end

      # Set the coordinator agent type.
      #
      # @param type [Symbol] Agent type: :code (writes code) or :tool (uses tool calling)
      # @return [TeamBuilder] New builder with coordinator type set
      #
      # @example Setting coordinator type
      #   builder = Smolagents.team.coordinator(:tool)
      #   builder.config[:coordinator_type]
      #   #=> :tool
      def coordinator(type) = with_config(coordinator_type: type.to_sym)

      # Set the maximum steps for the coordinator agent.
      #
      # @param count [Integer] Maximum steps (1-Config::MAX_STEPS_LIMIT)
      # @return [TeamBuilder] New builder with max steps set
      #
      # @example Setting max steps
      #   builder = Smolagents.team.max_steps(25)
      #   builder.config[:max_steps]
      #   #=> 25
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Configure planning for the coordinator.
      #
      # @param interval [Integer] Steps between re-planning
      # @return [TeamBuilder] New builder with planning configured
      #
      # @example Enabling planning
      #   builder = Smolagents.team.planning(interval: 5)
      #   builder.config[:planning_interval]
      #   #=> 5
      def planning(interval:) = with_config(planning_interval: interval)

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
        agent_config = Types::AgentConfig.create(
          custom_instructions: cfg[:coordinator_instructions],
          max_steps: cfg[:max_steps],
          planning_interval: cfg[:planning_interval]
        )
        agent_class.new(
          model:, tools: [], managed_agents: build_managed_agents, config: agent_config
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
