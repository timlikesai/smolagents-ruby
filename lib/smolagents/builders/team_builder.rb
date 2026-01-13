module Smolagents
  module Builders
    # Chainable builder for composing multi-agent teams.
    #
    # Built using Ruby 4.0 Data.define for immutability and pattern matching.
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
    TeamBuilder = Data.define(:configuration) do
      include Base

      # Default configuration hash
      #
      # @return [Hash] Default configuration
      def self.default_configuration
        {
          agents: {},
          model_block: nil,
          coordinator_instructions: nil,
          coordinator_type: :code,
          max_steps: nil,
          planning_interval: nil,
          callbacks: []
        }
      end

      # Factory method to create a new builder
      #
      # @return [TeamBuilder] New builder instance
      def self.create
        new(configuration: default_configuration)
      end

      # Register builder methods for validation and help
      builder_method :agent,
                     description: "Add an agent to the team - as: name for the agent",
                     required: true

      builder_method :max_steps,
                     description: "Set maximum steps for coordinator (1-1000, default: 10)",
                     validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 },
                     aliases: [:steps]

      builder_method :coordinate,
                     description: "Set coordination instructions",
                     validates: ->(v) { v.is_a?(String) && !v.empty? },
                     aliases: [:instructions]

      # Set the shared model for the coordinator (and optionally sub-agents)
      #
      # @yield Block that returns a Model instance
      # @return [TeamBuilder] New builder with model configured
      def model(&block)
        with_config(model_block: block)
      end

      # Add an agent to the team
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for this team member
      # @return [TeamBuilder] New builder with agent added
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end
      alias_method :add_agent, :agent

      # Set coordination instructions for the team
      #
      # @param instructions [String] Instructions for coordinating sub-agents
      # @return [TeamBuilder] New builder with instructions set
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end
      alias_method :instructions, :coordinate

      # Set the coordinator agent type
      #
      # @param type [Symbol] :code or :tool_calling
      # @return [TeamBuilder] New builder with coordinator type set
      def coordinator(type)
        with_config(coordinator_type: type.to_sym)
      end

      # Set maximum steps for the coordinator
      #
      # @param n [Integer] Maximum steps
      # @return [TeamBuilder] New builder with max_steps set
      def max_steps(n)
        check_frozen!
        validate!(:max_steps, n)
        with_config(max_steps: n)
      end
      alias_method :steps, :max_steps

      # Configure planning for the coordinator
      #
      # @param interval [Integer] Steps between planning updates
      # @return [TeamBuilder] New builder with planning configured
      def planning(interval:)
        with_config(planning_interval: interval)
      end

      # Register a callback on the coordinator
      #
      # @param event [Symbol] Event name
      # @yield Block to call when event fires
      # @return [TeamBuilder] New builder with callback added
      def on(event, &block)
        check_frozen!
        with_config(callbacks: configuration[:callbacks] + [[event, block]])
      end

      # Convenience callback methods for common events

      # Register callback for before each step
      # @yield [step] Block to call before step execution
      # @return [TeamBuilder] New builder with callback added
      def on_step_start(&)
        on(:before_step, &)
      end

      # Register callback for after each step
      # @yield [step] Block to call after step execution
      # @return [TeamBuilder] New builder with callback added
      def on_step_complete(&)
        on(:after_step, &)
      end

      # Register callback for after task execution
      # @yield [result] Block to call after task completes
      # @return [TeamBuilder] New builder with callback added
      def on_task_complete(&)
        on(:after_task, &)
      end

      # Register callback for managed agent calls
      # @yield [agent_name, task] Block to call when delegating to sub-agent
      # @return [TeamBuilder] New builder with callback added
      def on_agent_call(&)
        on(:agent_call, &)
      end

      # Build the team (coordinator agent with managed sub-agents)
      #
      # @return [Agent] Coordinator agent with managed sub-agents
      # @raise [ArgumentError] If no agents added or no model available
      def build
        validate_config!

        model_instance = resolve_model
        agent_class_name = Builders::AGENT_TYPES.fetch(configuration[:coordinator_type])
        agent_class = Object.const_get(agent_class_name)

        # Convert agents hash to array of ManagedAgentTools with proper names
        managed_agent_tools = configuration[:agents].map do |name, agent|
          ManagedAgentTool.new(agent: agent, name: name)
        end

        coordinator = agent_class.new(
          model: model_instance,
          tools: [],
          managed_agents: managed_agent_tools,
          custom_instructions: configuration[:coordinator_instructions],
          max_steps: configuration[:max_steps],
          planning_interval: configuration[:planning_interval]
        )

        # Register callbacks
        configuration[:callbacks].each do |event, block|
          coordinator.register_callback(event, &block)
        end

        coordinator
      end

      # Get current configuration (for inspection)
      #
      # @return [Hash] Current configuration
      def config
        configuration.dup
      end

      # Inspect for debugging
      def inspect
        agent_names = configuration[:agents].keys.join(", ")
        "#<TeamBuilder agents=[#{agent_names}] coordinator=#{configuration[:coordinator_type]}>"
      end

      private

      # Immutable update helper - creates new builder with merged config
      #
      # @param kwargs [Hash] Configuration changes
      # @return [TeamBuilder] New builder instance
      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
      end

      def resolve_agent(agent_or_builder)
        case agent_or_builder
        when AgentBuilder
          # If builder has no model but we have a shared model, inject it
          agent_or_builder = agent_or_builder.model(&configuration[:model_block]) if agent_or_builder.config[:model_block].nil? && configuration[:model_block]
          agent_or_builder.build
        else
          agent_or_builder
        end
      end

      def resolve_model
        if configuration[:model_block]
          configuration[:model_block].call
        elsif configuration[:agents].any?
          # Use model from first agent
          configuration[:agents].values.first.model
        else
          raise ArgumentError, "Model required. Use .model { } or add agents with models"
        end
      end

      def validate_config!
        raise ArgumentError, "At least one agent required. Use .agent(agent, as: 'name')" if configuration[:agents].empty?
      end
    end
  end
end
