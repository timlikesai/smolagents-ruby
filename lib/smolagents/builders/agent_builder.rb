require_relative "execution_concern"
require_relative "inline_tool_concern"
require_relative "memory_concern"
require_relative "planning_concern"
require_relative "spawn_concern"
require_relative "specialization_concern"
require_relative "tool_resolution"

module Smolagents
  module Builders
    # Chainable builder for configuring agents with a fluent DSL.
    #
    # AgentBuilder provides a composable, immutable builder pattern for creating
    # agents. Each method returns a new builder instance, allowing safe chaining
    # without mutation.
    #
    # == Core Concepts
    #
    # Build agents with composable atoms:
    # - **Model**: +.model(instance)+ or +.model { }+ - the LLM (required)
    # - **Tools**: +.tools(:search)+ - what the agent can use (toolkits auto-expand)
    # - **Persona**: +.as(:researcher)+ or +.persona(:researcher)+ - behavioral instructions only
    # - **Specialization**: +.with(:researcher)+ - convenience (tools + persona)
    #
    # == Method Distinctions
    #
    # Understanding the three configuration methods:
    #
    #   .tools(:search)              - Adds toolkit tools (what agent CAN do)
    #   .as(:researcher)             - Adds persona instructions (HOW agent behaves)
    #   .persona(:researcher)        - Same as .as (alias)
    #   .with(:researcher)           - Convenience: adds both tools AND persona
    #
    # The relationship:
    #   .with(:researcher) == .tools(:research).as(:researcher)
    #
    # == When to Use Each
    #
    # Use +.tools+ when you want specific tools without behavioral changes:
    #   .tools(:search, :web)    # Just add tools
    #
    # Use +.as+ when you want behavioral instructions without adding tools:
    #   .tools(:search).as(:researcher)    # Tools + custom behavior
    #
    # Use +.with+ for quick setup with sensible defaults:
    #   .with(:researcher)    # Researcher tools + behavior in one call
    #
    # == Available Options
    #
    # Toolkits (for +.tools+): :search, :web, :data, :research
    # Personas (for +.as+): :researcher, :fact_checker, :analyst, :calculator, :scraper
    # Specializations (for +.with+): :researcher, :fact_checker, :data_analyst, :calculator, :web_scraper
    #
    # @example Minimal agent with model block
    #   agent = Smolagents.agent
    #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    #     .build
    #   agent.class.name
    #   #=> "Smolagents::Agents::Agent"
    #
    # @example Building with tools
    #   builder = Smolagents.agent.tools(:search, :web)
    #   builder.config[:tool_names].size > 0
    #   #=> true
    #
    # @example Building with specialization
    #   builder = Smolagents.agent.with(:researcher)
    #   builder.config[:tool_names].size > 0
    #   #=> true
    #
    # @example Chaining multiple configuration methods
    #   builder = Smolagents.agent
    #     .with(:researcher)
    #     .instructions("Be concise")
    #     .max_steps(15)
    #   builder.config[:max_steps]
    #   #=> 15
    #
    # @see Toolkits Available toolkits
    # @see Personas Available personas
    # @see Specializations Available specializations
    AgentBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers
      include ExecutionConcern
      include InlineToolConcern
      include MemoryConcern
      include PlanningConcern
      include SpawnConcern
      include SpecializationConcern
      include ToolResolution

      define_handler :tool, maps_to: :tool_complete

      def self.default_configuration
        { model_block: nil, tool_names: [], tool_instances: [], planning_interval: nil, planning_templates: nil,
          max_steps: nil, custom_instructions: nil, executor: nil, authorized_imports: nil, managed_agents: {},
          handlers: [], logger: nil, memory_config: nil, spawn_config: nil, evaluation_enabled: true }
      end

      # Create a new builder.
      # @return [AgentBuilder]
      def self.create
        new(configuration: default_configuration)
      end

      register_method :model, description: "Set model (required)", required: true
      register_method :max_steps, description: "Set max steps (1-#{Config::MAX_STEPS_LIMIT})",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }
      register_method :planning, description: "Configure planning interval"
      register_method :memory, description: "Configure memory management (budget, strategy)"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :persona, description: "Apply a persona (alias for .as)"
      register_method :with, description: "Add specialization"
      register_method :can_spawn, description: "Configure spawn capability"
      register_method :evaluation, description: "Enable structured evaluation phase"

      # Set model via instance, block, or registered name.
      #
      # Supports three patterns for maximum flexibility:
      # - **Instance** (eager): `.model(my_model)` - pass a model directly
      # - **Block** (lazy): `.model { OpenAIModel.lm_studio("gemma") }` - deferred creation
      # - **Symbol** (lazy): `.model(:local)` - reference a registered model
      #
      # Lazy instantiation defers connection setup, API key validation,
      # and resource allocation until `.build` is called.
      #
      # @overload model(instance)
      #   Pass a model instance directly (eager instantiation).
      #   @param instance [Model] A model instance
      #   @return [AgentBuilder]
      #
      # @overload model(&block)
      #   Set model via block (lazy instantiation). The block is called at build time.
      #   @yield Block that returns a Model instance
      #   @return [AgentBuilder]
      #
      # @overload model(registered_name)
      #   Reference a model registered in configuration. Also lazy - the
      #   registered factory is called at build time.
      #   @param registered_name [Symbol] Name of a registered model
      #   @return [AgentBuilder]
      #
      # @raise [ArgumentError] If neither instance, name, nor block provided
      #
      # @example Using a block (lazy instantiation)
      #   builder = Smolagents.agent.model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #   builder.config[:model_block].nil?
      #   #=> false
      #
      # @example Using a direct instance
      #   model = Smolagents::OpenAIModel.new(model_id: "gpt-4")
      #   builder = Smolagents.agent.model(model)
      #   builder.config[:model_block].nil?
      #   #=> false
      def model(instance_or_name = nil, &block)
        check_frozen!
        with_config(model_block: resolve_model_block(instance_or_name, block))
      end

      # Add tools by name, toolkit, or instance.
      #
      # Toolkit names (`:search`, `:web`, `:data`, `:research`) are automatically
      # expanded to their tool lists. Tool instances can be passed directly.
      #
      # @param names_or_instances [Array<Symbol, String, Tool>] Tools, toolkits, or instances
      # @return [AgentBuilder] New builder with tools added
      #
      # @example Adding a single toolkit
      #   builder = Smolagents.agent.tools(:search)
      #   builder.config[:tool_names].size > 0
      #   #=> true
      #
      # @example Combining multiple toolkits
      #   builder = Smolagents.agent.tools(:search, :web)
      #   builder.config[:tool_names].size >= 2
      #   #=> true
      #
      # @example Adding tool instances
      #   tool = Smolagents::Tools::FinalAnswerTool.new
      #   builder = Smolagents.agent.tools(tool)
      #   builder.config[:tool_instances].size
      #   #=> 1
      def tools(*names_or_instances)
        check_frozen!
        names, instances = partition_tool_args(names_or_instances.flatten)
        with_config(tool_names: configuration[:tool_names] + expand_toolkits(names),
                    tool_instances: configuration[:tool_instances] + instances)
      end

      # Set the maximum number of steps the agent can take.
      #
      # @param count [Integer] Maximum steps (1-Config::MAX_STEPS_LIMIT)
      # @return [AgentBuilder] New builder with max_steps configured
      #
      # @example Setting max steps
      #   builder = Smolagents.agent.max_steps(20)
      #   builder.config[:max_steps]
      #   #=> 20
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Add custom instructions to the agent's system prompt.
      #
      # Multiple calls to this method append instructions rather than replace them.
      #
      # @param text [String] Custom instructions to add
      # @return [AgentBuilder] New builder with instructions added
      #
      # @example Adding custom instructions
      #   builder = Smolagents.agent.instructions("Be concise and factual")
      #   builder.config[:custom_instructions]
      #   #=> "Be concise and factual"
      #
      # @example Chaining instructions
      #   builder = Smolagents.agent
      #     .instructions("Be concise")
      #     .instructions("Use bullet points")
      #   builder.config[:custom_instructions].include?("bullet points")
      #   #=> true
      def instructions(text)
        check_frozen!
        validate!(:instructions, text)
        current = configuration[:custom_instructions]
        merged = current ? "#{current}\n\n#{text}" : text
        with_config(custom_instructions: merged)
      end

      # Set the code execution environment.
      #
      # @param executor [Executor] Code execution environment (RubyExecutor, DockerExecutor, etc.)
      # @return [AgentBuilder] New builder with executor configured
      #
      # @example Setting a custom executor
      #   executor = Object.new  # Any executor instance
      #   builder = Smolagents.agent.executor(executor)
      #   builder.config[:executor].nil?
      #   #=> false
      def executor(executor) = with_config(executor:)

      # Set authorized Ruby libraries for code execution.
      #
      # @param imports [Array<String>] Authorized Ruby libraries (e.g., "json", "csv")
      # @return [AgentBuilder] New builder with imports configured
      #
      # @example Authorizing imports
      #   builder = Smolagents.agent.authorized_imports("json", "csv")
      #   builder.config[:authorized_imports]
      #   #=> ["json", "csv"]
      def authorized_imports(*imports) = with_config(authorized_imports: imports.flatten)

      # Set a custom logger for the agent.
      #
      # @param logger [Logger] Custom logger instance
      # @return [AgentBuilder] New builder with logger configured
      def logger(logger) = with_config(logger:)

      # Configure the structured evaluation phase for metacognition.
      #
      # Evaluation is ENABLED BY DEFAULT. After each step, the agent performs
      # a lightweight model call to check if the goal has been achieved. This
      # helps models that "forget" to call final_answer even when they have
      # the result.
      #
      # Only use this to DISABLE evaluation in special cases.
      #
      # @param enabled [Boolean] Whether evaluation is enabled (default: true)
      # @return [AgentBuilder] New builder with evaluation configured
      #
      # @example Disabling evaluation
      #   builder = Smolagents.agent.evaluation(enabled: false)
      #   builder.config[:evaluation_enabled]
      #   #=> false
      #
      # @example Evaluation is enabled by default
      #   builder = Smolagents.agent
      #   builder.config[:evaluation_enabled]
      #   #=> true
      def evaluation(enabled: true)
        check_frozen!
        with_config(evaluation_enabled: enabled)
      end

      # Add a managed sub-agent for multi-agent orchestration.
      #
      # Managed agents can be delegated tasks by the parent agent.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Sub-agent or builder
      # @param as [String, Symbol] Name for the sub-agent (used for delegation)
      # @return [AgentBuilder] New builder with managed agent added
      #
      # @example Adding a managed agent
      #   sub_agent = Smolagents.agent
      #     .tools(:search)
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .build
      #   builder = Smolagents.agent.managed_agent(sub_agent, as: :researcher)
      #   builder.config[:managed_agents].key?("researcher")
      #   #=> true
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with_config(managed_agents: configuration[:managed_agents].merge(as.to_s => resolved))
      end

      # Build the configured agent.
      #
      # Creates an Agent instance with all configured options. The model block
      # is evaluated at this point (lazy instantiation).
      #
      # @return [Agents::Agent] The configured agent
      # @raise [ArgumentError] If model is not configured
      #
      # @example Building an agent
      #   agent = Smolagents.agent
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .tools(:search)
      #     .max_steps(10)
      #     .build
      #   agent.class.name
      #   #=> "Smolagents::Agents::Agent"
      def build
        agent = Agents::Agent.new(**build_agent_args)
        configuration[:handlers].each { |event_type, block| agent.on(event_type, &block) }
        agent
      end

      def config = configuration.dup

      def inspect
        tools_desc = (configuration[:tool_names] + configuration[:tool_instances].map do |t|
          t.name || t.class.name
        end).join(", ")
        "#<AgentBuilder tools=[#{tools_desc}] handlers=#{configuration[:handlers].size}>"
      end

      private

      def build_agent_args
        cfg = configuration
        {
          model: resolve_model,
          tools: resolve_tools,
          config: build_agent_config(cfg),
          managed_agents: cfg[:managed_agents].empty? ? nil : cfg[:managed_agents],
          logger: cfg[:logger],
          executor: cfg[:executor]
        }.compact
      end

      def build_agent_config(cfg)
        Types::AgentConfig.create(
          max_steps: cfg[:max_steps],
          planning_interval: cfg[:planning_interval],
          planning_templates: cfg[:planning_templates],
          custom_instructions: cfg[:custom_instructions],
          evaluation_enabled: cfg[:evaluation_enabled],
          authorized_imports: cfg[:authorized_imports],
          spawn_config: cfg[:spawn_config],
          memory_config: cfg[:memory_config]
        )
      end

      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
      end

      def resolve_model_block(instance_or_name, block)
        case instance_or_name
        when Symbol then -> { Smolagents.get_model(instance_or_name) }
        when nil
          raise ArgumentError, "Model required: provide instance, symbol, or block" unless block

          block
        else -> { instance_or_name }
        end
      end

      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless configuration[:model_block]

        configuration[:model_block].call
      end
    end
  end
end
