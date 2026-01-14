module Smolagents
  module Builders
    # Chainable builder for composing multi-agent teams.
    #
    # TeamBuilder enables creating coordinator agents that manage a team of
    # sub-agents. Each sub-agent is given a name and can be invoked by the
    # coordinator to delegate work. Useful for decomposing complex tasks into
    # specialized sub-agents.
    #
    # Built using Ruby 4.0 Data.define for immutability and pattern matching.
    #
    # @example Basic team
    #   researcher = Smolagents.agent(:code)
    #     .model { OpenAIModel.new(...) }
    #     .tools(:search)
    #     .build
    #
    #   writer = Smolagents.agent(:code)
    #     .model { OpenAIModel.new(...) }
    #     .tools(:write_file)
    #     .build
    #
    #   team = Smolagents.team
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Coordinate: first research, then write a summary")
    #     .build
    #
    #   result = team.run("Write an article about Ruby")
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
    # @see Smolagents.team Factory method to create builders
    # @see Agents::Agent#run Execute a task with the team
    # @see AgentBuilder To build individual agents
    # @see ModelBuilder To configure models
    TeamBuilder = Data.define(:configuration) do
      include Base

      # Default configuration hash.
      #
      # Returns a hash containing default values for all team configuration options.
      # Used when creating a new builder to ensure all keys are initialized.
      #
      # @return [Hash] Default configuration with all keys set to nil or empty values:
      #   - agents: Team members by name
      #   - model_block: Shared model block for team (optional)
      #   - coordinator_instructions: Instructions for coordinator agent
      #   - coordinator_type: Agent type for coordinator (:code or :tool_calling)
      #   - max_steps: Maximum coordinator steps
      #   - planning_interval: Steps between planning
      #   - handlers: Event handlers
      #
      # @api private
      def self.default_configuration
        {
          agents: {},
          model_block: nil,
          coordinator_instructions: nil,
          coordinator_type: :code,
          max_steps: nil,
          planning_interval: nil,
          handlers: []
        }
      end

      # Factory method to create a new builder.
      #
      # Creates a TeamBuilder instance with default configuration.
      # Agents and coordination instructions can then be configured via method chaining.
      #
      # @return [TeamBuilder] New builder instance
      #
      # @example Creating a team builder
      #   builder = TeamBuilder.create
      #   team = builder
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .coordinate("Coordinate the team...")
      #     .build
      #
      # @see Smolagents.team Recommended factory method
      def self.create
        new(configuration: default_configuration)
      end

      # Register builder methods for validation and help
      builder_method :agent,
                     description: "Add an agent to the team - as: name for the agent",
                     required: true

      builder_method :max_steps,
                     description: "Set maximum steps for coordinator (1-1000, default: 10)",
                     validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }

      builder_method :coordinate,
                     description: "Set coordination instructions",
                     validates: ->(v) { v.is_a?(String) && !v.empty? }

      # Set the shared model for the coordinator (and optionally sub-agents).
      #
      # Specifies a model block that can be used by the coordinator and injected
      # into agent builders that don't have their own model. Useful for ensuring
      # all team members use the same LLM.
      #
      # @yield Block that returns a Model instance
      #
      # @return [TeamBuilder] New builder with model configured
      #
      # @example Setting shared model
      #   team = Smolagents.team
      #     .model { OpenAIModel.new(model_id: "gpt-4") }
      #     .agent(researcher_builder, as: "researcher")
      #     .build
      #
      # @see AgentBuilder#model Set model on individual agents
      def model(&block)
        with_config(model_block: block)
      end

      # Add an agent to the team.
      #
      # Adds a sub-agent to the team with a given name. The agent can be an
      # existing Agent instance or an AgentBuilder. If it's a builder without
      # a model and the team has a shared model, the builder's model will be
      # automatically injected.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for this team member (required, non-empty)
      #
      # @return [TeamBuilder] New builder with agent added
      #
      # @raise [ArgumentError] If agent name is empty
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Adding built agents
      #   researcher = Smolagents.agent(:code).model { model }.tools(:search).build
      #   writer = Smolagents.agent(:code).model { model }.tools(:file).build
      #   team = Smolagents.team
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .coordinate("...")
      #     .build
      #
      # @example Adding agent builders with shared model
      #   team = Smolagents.team
      #     .model { shared_model }
      #     .agent(
      #       Smolagents.agent(:code).tools(:search),
      #       as: "researcher"
      #     )
      #     .agent(
      #       Smolagents.agent(:code).tools(:file),
      #       as: "writer"
      #     )
      #     .coordinate("...")
      #     .build
      #
      # @see #model Set shared model for team
      # @see AgentBuilder To build agents
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end

      # Set coordination instructions for the team.
      #
      # Provides custom instructions for the coordinator agent on how to manage
      # and delegate to sub-agents.
      #
      # @param instructions [String] Instructions for coordinating sub-agents (required, non-empty)
      #
      # @return [TeamBuilder] New builder with instructions set
      #
      # @raise [ArgumentError] If instructions are empty
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting coordination instructions
      #   team.coordinate("First call researcher to find information, then call writer to summarize it.")
      #
      # @see #coordinator Set coordinator agent type
      # @see #max_steps Limit coordinator execution
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end

      # Set the coordinator agent type.
      #
      # Specifies whether the coordinator should be a CodeAgent (writes Ruby code)
      # or ToolCallingAgent (calls tools via JSON).
      #
      # @param type [Symbol] :code or :tool_calling (default: :code)
      #
      # @return [TeamBuilder] New builder with coordinator type set
      #
      # @example Using tool-calling coordinator
      #   team = Smolagents.team
      #     .agent(researcher, as: "researcher")
      #     .coordinator(:tool_calling)
      #     .build
      #
      # @see Agents::CodeAgent Coordinator that writes Ruby code
      # @see Agents::ToolCallingAgent Coordinator that calls tools via JSON
      def coordinator(type)
        with_config(coordinator_type: type.to_sym)
      end

      # Set maximum steps for the coordinator.
      #
      # Limits the number of steps (actions) the coordinator can take.
      # Prevents infinite loops and controls resource usage.
      #
      # @param n [Integer] Maximum steps (1-1000)
      #
      # @return [TeamBuilder] New builder with max_steps set
      #
      # @raise [ArgumentError] If n is outside valid range
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting max steps
      #   team = Smolagents.team
      #     .agent(agent1, as: "a1")
      #     .agent(agent2, as: "a2")
      #     .max_steps(20)
      #     .build
      #
      # @see AgentBuilder#max_steps Similar configuration for individual agents
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Configure planning for the coordinator.
      #
      # Enables periodic planning/reflection for the coordinator at specified intervals.
      #
      # @param interval [Integer] Steps between planning updates
      #
      # @return [TeamBuilder] New builder with planning configured
      #
      # @example Enabling planning every 3 steps
      #   team.planning(interval: 3)
      #
      # @see AgentBuilder#planning Similar configuration for individual agents
      def planning(interval:)
        with_config(planning_interval: interval)
      end

      # Subscribe to events.
      #
      # Registers an event handler for the coordinator. Events include step
      # completion, task completion, sub-agent completion, and errors.
      #
      # @param event_type [Class, Symbol] Event class or name (:step_complete, :task_complete, :agent_complete, etc.)
      # @yield [event] Block to call when event fires
      #
      # @return [TeamBuilder] New builder with handler added
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Subscribing to events
      #   team = builder
      #     .on(:step_complete) { |e| log("Coordinator step #{e.step_number}") }
      #     .on(:agent_complete) { |e| log("Sub-agent completed") }
      #     .build
      #
      # @see #on_step Convenience method for step events
      # @see #on_task Convenience method for task events
      # @see #on_agent Convenience method for agent events
      def on(event_type, &block)
        check_frozen!
        with_config(handlers: configuration[:handlers] + [[event_type, block]])
      end

      # Subscribe to coordinator step completion events.
      #
      # Registers a handler to be called after each coordinator step.
      # Useful for logging coordinator progress, monitoring decision-making,
      # or implementing custom step-level logic during team coordination.
      #
      # @yield [event] Step event
      # @yieldparam event [Object] Event object with step details (step_number, action, etc.)
      #
      # @return [TeamBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Logging coordinator steps
      #   team = Smolagents.team
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .on_step { |step| puts "Coordinator step #{step.number}" }
      #     .build
      #
      # @example Monitoring team decisions
      #   team = Smolagents.team
      #     .agent(agent1, as: "a1")
      #     .agent(agent2, as: "a2")
      #     .on_step { |s| log_decision(s.action, s.timestamp) }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_task Subscribe to overall task completion
      # @see #on_agent Subscribe to sub-agent completion
      def on_step(&) = on(:step_complete, &)

      # Subscribe to coordinator task completion events.
      #
      # Registers a handler to be called when the coordinator completes the
      # overall task. Useful for finalizing team results, aggregating outputs,
      # or implementing post-team cleanup.
      #
      # @yield [event] Task completion event
      # @yieldparam event [Object] Event object with final result and team state
      #
      # @return [TeamBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Aggregating team results
      #   team = Smolagents.team
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .on_task { |result| aggregate_and_save(result) }
      #     .build
      #
      # @example Team completion cleanup
      #   team = Smolagents.team
      #     .agent(agent1, as: "a1")
      #     .agent(agent2, as: "a2")
      #     .on_task { |result| cleanup_temp_files }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_step Subscribe to coordinator steps
      # @see Agents::Agent#run Task execution method
      def on_task(&) = on(:task_complete, &)

      # Subscribe to sub-agent completion events.
      #
      # Registers a handler to be called when a sub-agent completes its work.
      # Useful for tracking individual agent contributions, aggregating results,
      # or coordinating dependent tasks.
      #
      # @yield [event] Sub-agent completion event
      # @yieldparam event [Object] Event object with agent name and result details
      #
      # @return [TeamBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Tracking sub-agent results
      #   team = Smolagents.team
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .on_agent { |event| log("Agent #{event.name} completed") }
      #     .build
      #
      # @example Aggregating agent outputs
      #   team = Smolagents.team
      #     .agent(analyzer, as: "analyzer")
      #     .agent(optimizer, as: "optimizer")
      #     .on_agent { |e| results[e.name] = e.output }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_step Subscribe to coordinator steps
      # @see #agent Add sub-agents to the team
      def on_agent(&) = on(:agent_complete, &)

      # Build the team (coordinator agent with managed sub-agents).
      #
      # Creates an Agent instance that coordinates a team of sub-agents.
      # The coordinator can call any sub-agent to delegate work. Validates
      # that at least one agent is added and a model is available.
      #
      # @return [Agent] Coordinator agent with managed sub-agents attached
      #
      # @raise [ArgumentError] If no agents added, no model available, or configuration invalid
      #
      # @example Building a team
      #   team = Smolagents.team
      #     .model { model }
      #     .agent(researcher, as: "researcher")
      #     .agent(writer, as: "writer")
      #     .coordinate("Coordinate the team...")
      #     .build
      #   result = team.run("Write about Ruby")
      #
      # @see TeamBuilder Factory method to start building
      # @see Agents::Agent#run Execute task with the team
      # @see #agent Add sub-agents to team
      # @see #coordinate Set coordinator instructions
      def build
        validate_config!
        coordinator = build_coordinator(resolve_model, resolve_agent_class)
        register_handlers(coordinator)
        coordinator
      end

      private

      def resolve_agent_class = Object.const_get(Builders::AGENT_TYPES.fetch(configuration[:coordinator_type]))

      def build_managed_agents = configuration[:agents].map { |name, agent| ManagedAgentTool.new(agent:, name:) }

      def build_coordinator(model, agent_class)
        agent_class.new(model:, tools: [], managed_agents: build_managed_agents, custom_instructions: configuration[:coordinator_instructions],
                        max_steps: configuration[:max_steps], planning_interval: configuration[:planning_interval])
      end

      def register_handlers(coordinator)
        configuration[:handlers].each { |event_type, block| coordinator.on(event_type, &block) }
      end

      public

      # Get current configuration (for inspection)
      # @return [Hash] Current configuration
      def config = configuration.dup

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
