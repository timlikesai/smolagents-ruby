module Smolagents
  module Builders
    # Chainable builder for configuring and creating agents.
    #
    # AgentBuilder provides a fluent DSL for constructing agents with models,
    # tools, execution parameters, and event handlers. Supports both CodeAgent
    # (which writes Ruby code) and ToolCallingAgent (which calls tools via JSON).
    #
    # Built using Ruby 4.0 Data.define for immutability and pattern matching.
    #
    # @example Basic code agent
    #   agent = Smolagents.agent(:code)
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .tools(:google_search, :visit_webpage)
    #     .max_steps(10)
    #     .build
    #   result = agent.run("What is the weather in Tokyo?")
    #
    # @example Tool-calling agent
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { AnthropicModel.new(model_id: "claude-3") }
    #     .tools(:search, :calculate)
    #     .build
    #
    # @example With planning and callbacks
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { AnthropicModel.new(model_id: "claude-3") }
    #     .tools(:search, custom_tool)
    #     .planning(interval: 3)
    #     .on(:step_complete) { |step| puts "Step #{step.number}" }
    #     .on(:task_complete) { |result| save_result(result) }
    #     .build
    #
    # @see Smolagents.agent Factory method to create builders
    # @see Agents::CodeAgent Agent that writes Ruby code
    # @see Agents::ToolCallingAgent Agent that calls tools via JSON
    AgentBuilder = Data.define(:agent_type, :configuration) do
      include Base

      # Default configuration hash.
      #
      # Returns a hash containing default values for all agent configuration options.
      # Used when creating a new builder to ensure all keys are initialized.
      #
      # @return [Hash] Default configuration with all keys set to nil or empty values:
      #   - model_block: Block that creates the model
      #   - tool_names: Tool names from registry
      #   - tool_instances: Tool instances
      #   - planning_interval: Steps between planning
      #   - planning_templates: Custom planning prompts
      #   - max_steps: Maximum execution steps
      #   - custom_instructions: Custom system instructions
      #   - executor: Code execution environment (code agents)
      #   - authorized_imports: Allowed imports (code agents)
      #   - managed_agents: Sub-agents by name
      #   - handlers: Event handlers [[event_type, block], ...]
      #   - logger: Agent logger instance
      #
      # @api private
      def self.default_configuration
        {
          model_block: nil,
          tool_names: [],
          tool_instances: [],
          planning_interval: nil,
          planning_templates: nil,
          max_steps: nil,
          custom_instructions: nil,
          executor: nil,
          authorized_imports: nil,
          managed_agents: {},
          handlers: [],
          logger: nil
        }
      end

      # Factory method to create a new builder.
      #
      # Creates an AgentBuilder instance with the given agent type.
      # The builder starts with default configuration and can be customized
      # via method chaining.
      #
      # @param agent_type [Symbol] Agent type - :code or :tool_calling
      #
      # @return [AgentBuilder] New builder instance
      #
      # @raise [ArgumentError] If agent_type is invalid (checked during build)
      #
      # @example Creating a code agent builder
      #   builder = AgentBuilder.create(:code)
      #   agent = builder
      #     .model { OpenAIModel.new(...) }
      #     .tools(:search)
      #     .build
      #
      # @see Smolagents.agent Recommended factory method
      def self.create(agent_type)
        new(agent_type: agent_type.to_sym, configuration: default_configuration)
      end

      # Register builder methods for validation and help
      builder_method :model,
                     description: "Set model (required) - Block should return a Model instance",
                     required: true

      builder_method :max_steps,
                     description: "Set maximum execution steps (1-1000, default: 10)",
                     validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }

      builder_method :planning,
                     description: "Configure planning - interval: steps between plans, templates: custom prompts"

      builder_method :instructions,
                     description: "Set custom instructions for the agent",
                     validates: ->(v) { v.is_a?(String) && !v.empty? }

      # Set the model via a block (deferred evaluation).
      #
      # The model block is called during {#build} to create the model instance.
      # This allows for lazy initialization and dynamic model selection based on
      # environment variables or other runtime conditions.
      #
      # @yield Block that returns a Model instance
      #
      # @return [AgentBuilder] New builder with model configured
      #
      # @raise [ArgumentError] If block is not provided
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting a model
      #   builder.model { OpenAIModel.new(model_id: "gpt-4") }
      #
      # @example Using environment-based model selection
      #   builder.model do
      #     if ENV["USE_CLAUDE"]
      #       AnthropicModel.new(model_id: "claude-3")
      #     else
      #       OpenAIModel.new(model_id: "gpt-4")
      #     end
      #   end
      #
      # @see Builders::ModelBuilder For model configuration
      # @see Agents::Agent#run Execute a task with the agent
      def model(&block)
        check_frozen!
        raise ArgumentError, "Model block required" unless block

        with_config(model_block: block)
      end

      # Add tools by name (from registry) or instance.
      #
      # Tools can be specified by name (Symbol or String) to look up in the
      # global tool registry, or as Tool instances. Supports mixing both types
      # in a single call.
      #
      # @param names_or_instances [Array<Symbol, String, Tool>] Tools to add
      #
      # @return [AgentBuilder] New builder with tools added
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Adding tools by name
      #   builder.tools(:google_search, :visit_webpage)
      #
      # @example Adding tool instances
      #   custom_tool = MyTool.new(api_key: "...")
      #   builder.tools(custom_tool)
      #
      # @example Mixing names and instances
      #   builder.tools(:search, custom_tool, :calculator)
      #
      # @see Tools.get Look up tools by name in registry
      # @see Tools::Tool Base class for creating tools
      def tools(*names_or_instances)
        check_frozen!
        names, instances = names_or_instances.flatten.partition do |t|
          t.is_a?(Symbol) || t.is_a?(String)
        end

        with_config(
          tool_names: configuration[:tool_names] + names.map(&:to_sym),
          tool_instances: configuration[:tool_instances] + instances
        )
      end

      # Configure planning.
      #
      # Planning allows the agent to think about its approach at regular intervals
      # during execution. Can be customized with interval (how often to plan) and
      # templates (custom planning prompts).
      #
      # @param interval [Integer, nil] Steps between planning updates
      # @param templates [Hash, nil] Custom planning templates
      #
      # @return [AgentBuilder] New builder with planning configured
      #
      # @example Configuring planning interval
      #   builder.planning(interval: 3)  # Plan every 3 steps
      #
      # @see Types::PlanningStep Step type for planning
      def planning(interval: nil, templates: nil)
        with_config(
          planning_interval: interval || configuration[:planning_interval],
          planning_templates: templates || configuration[:planning_templates]
        )
      end

      # Set maximum steps.
      #
      # Limits the number of steps (actions) the agent can take before
      # stopping. Prevents infinite loops and controls resource usage.
      #
      # @param n [Integer] Maximum number of steps (1-1000)
      #
      # @return [AgentBuilder] New builder with max_steps set
      #
      # @raise [ArgumentError] If n is not in valid range (1-1000)
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting max steps
      #   builder.max_steps(10)  # Allow up to 10 steps
      #
      # @see Agents::Agent#step Single step execution
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Set custom instructions.
      #
      # Allows specifying additional instructions for the agent beyond the
      # default system prompt. Useful for task-specific guidance.
      #
      # @param text [String] Custom instructions for the agent (must be non-empty)
      #
      # @return [AgentBuilder] New builder with instructions set
      #
      # @raise [ArgumentError] If text is empty
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting custom instructions
      #   builder.instructions("Always cite your sources in responses.")
      #
      # @see Types::SystemPromptStep System prompt handling
      def instructions(text)
        check_frozen!
        validate!(:instructions, text)
        with_config(custom_instructions: text)
      end

      # Set executor (for code agents).
      #
      # Specifies the execution environment for code agents. Determines how
      # Ruby code is executed (sandbox, Ractor, Docker, etc.).
      #
      # @param executor [Executor] Custom executor instance
      #
      # @return [AgentBuilder] New builder with executor set
      #
      # @example Setting a custom executor
      #   executor = Smolagents::Executors::Docker.new(image: "ruby:3.2")
      #   builder.executor(executor)
      #
      # @see Executors::Executor Base executor interface
      # @see Agents::CodeAgent Uses executor for code execution
      def executor(executor)
        with_config(executor:)
      end

      # Set authorized imports (for code agents).
      #
      # Specifies which Ruby libraries code agents are allowed to require.
      # Whitelist security control for sandboxed code execution.
      #
      # @param imports [Array<String>] Library names to authorize
      #
      # @return [AgentBuilder] New builder with imports set
      #
      # @example Setting authorized imports
      #   builder.authorized_imports("json", "net/http", "date")
      #
      # @see Executors::RubyExecutor Uses this for code sandboxing
      # @see Agents::CodeAgent Uses this to control requires
      def authorized_imports(*imports)
        with_config(authorized_imports: imports.flatten)
      end

      # Set logger.
      #
      # Specifies a custom logger for agent execution. Receives logs of agent
      # steps, tool calls, and other events.
      #
      # @param logger [AgentLogger] Logger instance
      #
      # @return [AgentBuilder] New builder with logger set
      #
      # @example Setting a custom logger
      #   builder.logger(MyLogger.new(output: $stderr))
      #
      # @see Logging::Subscriber Log event handling
      def logger(logger)
        with_config(logger:)
      end

      # Subscribe to events. Accepts event class or convenience name.
      #
      # Registers an event handler that will be called when the specified event
      # occurs during agent execution. Events include step completion, task completion,
      # errors, and tool usage.
      #
      # @param event_type [Class, Symbol] Event class or name (:step_complete, :task_complete, :error, :tool_complete, etc.)
      # @yield [event] Block to call when event fires
      #
      # @return [AgentBuilder] New builder with handler added
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Using event class
      #   .on(Events::StepCompleted) { |e| log(e.step_number) }
      #
      # @example Using convenience name
      #   .on(:step_complete) { |e| log(e.step_number) }
      #
      # @example Multiple handlers
      #   agent = builder
      #     .on(:step_complete) { |e| puts "Step #{e.step_number}" }
      #     .on(:error) { |e| puts "Error: #{e}" }
      #     .build
      #
      # @see #on_step Convenience method for step events
      # @see #on_task Convenience method for task events
      # @see #on_error Convenience method for error events
      def on(event_type, &block)
        check_frozen!
        with_config(handlers: configuration[:handlers] + [[event_type, block]])
      end

      # Subscribe to step completion events.
      #
      # Registers a handler to be called when the agent completes each step
      # (actions or observations). Useful for logging progress, monitoring,
      # or implementing custom step-level logic.
      #
      # @yield [event] Step completion event
      # @yieldparam event [Object] Event object with step details (step_number, type, etc.)
      #
      # @return [AgentBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Logging each step
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .tools(:search)
      #     .on_step { |step| puts "Step #{step.number}: #{step.type}" }
      #     .build
      #
      # @example Multiple step handlers
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .on_step { |s| log("Step", s) }
      #     .on_step { |s| metrics.track_step(s) }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_task Subscribe to task completion
      # @see #on_error Subscribe to errors
      def on_step(&) = on(:step_complete, &)

      # Subscribe to task completion events.
      #
      # Registers a handler to be called when the agent completes the overall task.
      # Useful for finalizing results, cleanup, or post-processing.
      #
      # @yield [event] Task completion event
      # @yieldparam event [Object] Event object with task result and final state
      #
      # @return [AgentBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Saving results
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .tools(:search)
      #     .on_task { |result| save_to_database(result) }
      #     .build
      #
      # @example Cleanup after task
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .on_task { |result| cleanup_temp_files }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_step Subscribe to step completion
      # @see Agents::Agent#run Task execution method
      def on_task(&) = on(:task_complete, &)

      # Subscribe to error events.
      #
      # Registers a handler to be called when an error occurs during agent execution.
      # Useful for error handling, logging, recovery, or custom error strategies.
      #
      # @yield [event] Error event
      # @yieldparam event [Object] Event object with error details (exception, step, etc.)
      #
      # @return [AgentBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Logging errors
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .tools(:search)
      #     .on_error { |error| logger.error("Agent error", error) }
      #     .build
      #
      # @example Error recovery strategy
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .on_error { |err| attempt_recovery(err) }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_step Subscribe to step completion
      # @see #on_tool Subscribe to tool usage
      def on_error(&) = on(:error, &)

      # Subscribe to tool completion events.
      #
      # Registers a handler to be called when the agent uses a tool.
      # Useful for monitoring tool usage, metrics collection, or debugging.
      #
      # @yield [event] Tool completion event
      # @yieldparam event [Object] Event object with tool details (name, arguments, result, etc.)
      #
      # @return [AgentBuilder] New builder with handler registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Tracking tool usage
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .tools(:search, :calculate)
      #     .on_tool { |tool| analytics.record_tool_call(tool.name) }
      #     .build
      #
      # @example Validating tool results
      #   agent = Smolagents.agent(:code)
      #     .model { model }
      #     .on_tool { |tool| validate_tool_result(tool) }
      #     .build
      #
      # @see #on Generic event subscription
      # @see #on_step Subscribe to step completion
      # @see Tools::Tool Base tool class
      def on_tool(&) = on(:tool_complete, &)

      # Add a managed sub-agent.
      #
      # Managed agents are sub-agents that this agent can delegate tasks to.
      # Each managed agent is given a name and can be called via special tool calls
      # from the parent agent. Useful for composing complex behaviors from simpler agents.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add as sub-agent
      # @param as [String, Symbol] Name for the managed agent (must be non-empty)
      #
      # @return [AgentBuilder] New builder with managed agent added
      #
      # @example Adding a sub-agent
      #   researcher = Smolagents.agent(:code)
      #     .model { OpenAIModel.new(...) }
      #     .tools(:search)
      #     .build
      #
      #   coordinator = Smolagents.agent(:code)
      #     .model { OpenAIModel.new(...) }
      #     .managed_agent(researcher, as: "researcher")
      #     .build
      #
      # @see Types::ManagedAgentTool How agents call sub-agents
      # @see AgentBuilder#build Creates the final agent
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with_config(managed_agents: configuration[:managed_agents].merge(as.to_s => resolved))
      end

      # Build the configured agent.
      #
      # Creates an immutable Agent instance from this builder's configuration.
      # Resolves model (by calling model block), tools (from registry and instances),
      # and sets up all execution parameters and event handlers.
      #
      # @return [Agent] Configured agent instance (CodeAgent or ToolCallingAgent)
      #
      # @raise [ArgumentError] If model not configured or tools not found in registry
      #
      # @example Building a code agent
      #   agent = builder
      #     .model { OpenAIModel.new(...) }
      #     .tools(:search)
      #     .build
      #   agent.run("Find information about Ruby 3.2")
      #
      # @example Building a tool-calling agent
      #   agent = Smolagents.agent(:tool_calling)
      #     .model { AnthropicModel.new(...) }
      #     .tools(:search, :calculate)
      #     .max_steps(5)
      #     .build
      #
      # @see Agents::Agent#run Execute a task with the agent
      # @see Agents::CodeAgent Writes Ruby code for tool calls
      # @see Agents::ToolCallingAgent Calls tools via JSON
      def build
        model_instance = resolve_model
        tools_array = resolve_tools

        agent_class_name = Builders::AGENT_TYPES.fetch(agent_type) do
          raise ArgumentError, "Unknown agent type: #{agent_type}. Valid types: #{Builders::AGENT_TYPES.keys.join(", ")}"
        end
        agent_class = Object.const_get(agent_class_name)

        agent_args = {
          model: model_instance,
          tools: tools_array,
          max_steps: configuration[:max_steps],
          planning_interval: configuration[:planning_interval],
          planning_templates: configuration[:planning_templates],
          custom_instructions: configuration[:custom_instructions],
          managed_agents: configuration[:managed_agents].empty? ? nil : configuration[:managed_agents],
          logger: configuration[:logger]
        }.compact

        # Add code-specific options
        if agent_type == :code
          agent_args[:executor] = configuration[:executor] if configuration[:executor]
          agent_args[:authorized_imports] = configuration[:authorized_imports] if configuration[:authorized_imports]
        end

        agent = agent_class.new(**agent_args)

        # Register event handlers
        configuration[:handlers].each do |event_type, block|
          agent.on(event_type, &block)
        end

        agent
      end

      # Get current configuration (for inspection).
      #
      # Returns a copy of the current builder configuration as a hash.
      # Useful for inspecting what has been configured before building.
      #
      # @return [Hash] Copy of current configuration
      #
      # @example Inspecting configuration
      #   builder = Smolagents.agent(:code)
      #     .model { OpenAIModel.new(...) }
      #     .tools(:search)
      #   puts builder.config[:tool_names]  # => [:search]
      #
      # @see #inspect Pretty print builder state
      def config = configuration.dup

      # Inspect for debugging.
      #
      # Returns a concise string representation of the builder showing the
      # agent type, configured tools, and number of event handlers.
      #
      # @return [String] Short builder description
      #
      # @example Inspecting builder
      #   builder = Smolagents.agent(:code).tools(:search)
      #   puts builder.inspect
      #   # => #<AgentBuilder type=code tools=[search] handlers=0>
      #
      # @see #config Get full configuration
      def inspect
        tools_desc = (configuration[:tool_names] + configuration[:tool_instances].map { |t| t.name || t.class.name }).join(", ")
        "#<AgentBuilder type=#{agent_type} tools=[#{tools_desc}] handlers=#{configuration[:handlers].size}>"
      end

      private

      # Immutable update helper - creates new builder with merged config.
      #
      # Creates a new AgentBuilder instance with the same agent_type but
      # with configuration merged with provided kwargs. Implements the
      # immutability pattern used throughout the builder.
      #
      # @param kwargs [Hash] Configuration changes to merge
      #
      # @return [AgentBuilder] New builder instance with merged config
      #
      # @api private
      def with_config(**kwargs)
        self.class.new(agent_type:, configuration: configuration.merge(kwargs))
      end

      # Resolve the model from the model block.
      #
      # Calls the model block to create the actual Model instance.
      # Called during {#build} to defer model creation.
      #
      # @return [Model] The created model instance
      #
      # @raise [ArgumentError] If model block was not configured
      #
      # @api private
      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless configuration[:model_block]

        configuration[:model_block].call
      end

      # Resolve tools from registry and instances.
      #
      # Looks up tool names in the global registry and combines them with
      # any tool instances that were added via {#tools}. Called during {#build}.
      #
      # @return [Array<Tool>] Combined tool instances
      #
      # @raise [ArgumentError] If a tool name is not found in registry
      #
      # @api private
      def resolve_tools
        # Resolve tools from registry by name
        registry_tools = configuration[:tool_names].map do |name|
          Tools.get(name.to_s) || raise(ArgumentError, "Unknown tool: #{name}. Available: #{Tools.names.join(", ")}")
        end

        # Combine with tool instances
        registry_tools + configuration[:tool_instances]
      end
    end
  end
end
