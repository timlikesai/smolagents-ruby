module Smolagents
  module Builders
    # Chainable builder for composing multi-agent teams.
    #
    # @example Basic team
    #   team = Smolagents.team
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research the topic, then write a summary")
    #     .build
    #
    # @example With shared model and inline agent builders
    #   team = Smolagents.team
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .agent(
    #       Smolagents.agent(:code).tools(:google_search, :visit_webpage),
    #       as: "researcher"
    #     )
    #     .agent(
    #       Smolagents.agent(:code).tools(:write_file),
    #       as: "writer"
    #     )
    #     .coordinate("Coordinate the research and writing team")
    #     .build
    #
    class TeamBuilder
      attr_reader :config

      def initialize(config = {})
        @config = {
          agents: {},
          model_block: nil,
          coordinator_instructions: nil,
          coordinator_type: :code,
          max_steps: nil,
          planning_interval: nil,
          callbacks: []
        }.merge(config).freeze
      end

      # Set the shared model for the coordinator (and optionally sub-agents)
      #
      # @yield Block that returns a Model instance
      # @return [TeamBuilder] New builder with model configured
      def model(&block)
        with(model_block: block)
      end

      # Add an agent to the team
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for this team member
      # @return [TeamBuilder] New builder with agent added
      def agent(agent_or_builder, as:)
        resolved = resolve_agent(agent_or_builder)
        with(agents: config[:agents].merge(as.to_s => resolved))
      end

      # Set coordination instructions for the team
      #
      # @param instructions [String] Instructions for coordinating sub-agents
      # @return [TeamBuilder] New builder with instructions set
      def coordinate(instructions)
        with(coordinator_instructions: instructions)
      end

      # Set the coordinator agent type
      #
      # @param type [Symbol] :code or :tool_calling
      # @return [TeamBuilder] New builder with coordinator type set
      def coordinator(type)
        with(coordinator_type: type.to_sym)
      end

      # Set maximum steps for the coordinator
      #
      # @param n [Integer] Maximum steps
      # @return [TeamBuilder] New builder with max_steps set
      def max_steps(n)
        with(max_steps: n)
      end

      # Configure planning for the coordinator
      #
      # @param interval [Integer] Steps between planning updates
      # @return [TeamBuilder] New builder with planning configured
      def planning(interval:)
        with(planning_interval: interval)
      end

      # Register a callback on the coordinator
      #
      # @param event [Symbol] Event name
      # @yield Block to call when event fires
      # @return [TeamBuilder] New builder with callback added
      def on(event, &block)
        with(callbacks: config[:callbacks] + [[event, block]])
      end

      # Build the team (coordinator agent with managed sub-agents)
      #
      # @return [Agent] Coordinator agent with managed sub-agents
      # @raise [ArgumentError] If no agents added or no model available
      def build
        validate_config!

        model_instance = resolve_model
        agent_class = AgentBuilder::AGENT_TYPES.fetch(config[:coordinator_type])

        # Convert agents hash to array of ManagedAgentTools with proper names
        managed_agent_tools = config[:agents].map do |name, agent|
          ManagedAgentTool.new(agent: agent, name: name)
        end

        coordinator = agent_class.new(
          model: model_instance,
          tools: [],
          managed_agents: managed_agent_tools,
          custom_instructions: config[:coordinator_instructions],
          max_steps: config[:max_steps],
          planning_interval: config[:planning_interval]
        )

        # Register callbacks
        config[:callbacks].each do |event, block|
          coordinator.register_callback(event, &block)
        end

        coordinator
      end

      # Inspect for debugging
      def inspect
        agent_names = config[:agents].keys.join(", ")
        "#<TeamBuilder agents=[#{agent_names}] coordinator=#{config[:coordinator_type]}>"
      end

      private

      def with(**changes)
        self.class.new(config.merge(changes))
      end

      def resolve_agent(agent_or_builder)
        case agent_or_builder
        when AgentBuilder
          # If builder has no model but we have a shared model, inject it
          agent_or_builder = agent_or_builder.model(&config[:model_block]) if agent_or_builder.config[:model_block].nil? && config[:model_block]
          agent_or_builder.build
        else
          agent_or_builder
        end
      end

      def resolve_model
        if config[:model_block]
          config[:model_block].call
        elsif config[:agents].any?
          # Use model from first agent
          config[:agents].values.first.model
        else
          raise ArgumentError, "Model required. Use .model { } or add agents with models"
        end
      end

      def validate_config!
        raise ArgumentError, "At least one agent required. Use .agent(agent, as: 'name')" if config[:agents].empty?
      end
    end
  end
end
