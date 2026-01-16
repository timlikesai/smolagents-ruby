module Smolagents
  module Builders
    # Chainable builder for configuring agents.
    #
    # All agents write Ruby code. Build with composable atoms:
    # - **Model**: `.model { }` - the LLM (required)
    # - **Tools**: `.tools(:search, :web)` - what the agent can use
    # - **Persona**: `.as(:researcher)` - behavioral instructions
    #
    # @example Minimal agent
    #   Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @example Agent with tools
    #   Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search, :web)
    #     .build
    #
    # @example Agent with persona
    #   Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search)
    #     .as(:researcher)
    #     .build
    #
    # @example Using specialization (combines tools + persona)
    #   Smolagents.agent
    #     .with(:researcher)
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    AgentBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers

      define_handler :tool, maps_to: :tool_complete

      def self.default_configuration
        { model_block: nil, tool_names: [], tool_instances: [], planning_interval: nil, planning_templates: nil,
          max_steps: nil, custom_instructions: nil, executor: nil, authorized_imports: nil, managed_agents: {},
          handlers: [], logger: nil, memory_config: nil, spawn_config: nil }
      end

      # Create a new builder.
      # @return [AgentBuilder]
      def self.create
        new(configuration: default_configuration)
      end

      register_method :model, description: "Set model (required)", required: true
      register_method :max_steps, description: "Set max steps (1-1000)",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }
      register_method :planning, description: "Configure planning interval"
      register_method :memory, description: "Configure memory management (budget, strategy)"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :with, description: "Add specialization"
      register_method :can_spawn, description: "Configure spawn capability"

      # Set model via block or registered name.
      #
      # @overload model { ... }
      #   Set model via block
      # @overload model(:role_name)
      #   Reference registered model by name
      # @return [AgentBuilder]
      def model(name = nil, &block)
        check_frozen!

        model_block = if name
                        -> { Smolagents.get_model(name) }
                      else
                        raise ArgumentError, "Model block required" unless block

                        block
                      end

        with_config(model_block:)
      end

      # Add tools by name, toolkit, or instance.
      #
      # Toolkit names (`:search`, `:web`, `:data`, `:research`) are automatically
      # expanded to their tool lists.
      #
      # @param names_or_instances [Array<Symbol, String, Tool>] Tools, toolkits, or instances
      # @return [AgentBuilder]
      #
      # @example Using toolkits
      #   .tools(:search)              # expands to search tools
      #   .tools(:search, :web)        # combine toolkits
      #   .tools(:search, :my_tool)    # mix toolkits and tools
      def tools(*names_or_instances)
        check_frozen!
        names, instances = partition_tool_args(names_or_instances.flatten)
        with_config(tool_names: configuration[:tool_names] + expand_toolkits(names),
                    tool_instances: configuration[:tool_instances] + instances)
      end

      # Add specialization (tools + persona bundle).
      #
      # @param names [Array<Symbol>] Specialization names
      # @return [AgentBuilder]
      #
      # @example
      #   .with(:researcher)     # adds research tools + researcher persona
      #   .with(:data_analyst)   # adds data tools + analyst persona
      def with(*names)
        check_frozen!
        names = names.flatten.map(&:to_sym)
        return self if names.empty?

        # :code is accepted but ignored - all agents write code now
        names = names.reject { |n| n == :code }
        return self if names.empty?

        collected = collect_specializations(names)
        build_with_specializations(collected)
      end

      # Configure planning (Pre-Act pattern).
      #
      # Research shows 70% improvement in Action Recall with planning enabled.
      # Planning creates a strategic plan before execution and updates it periodically.
      #
      # @overload planning
      #   Enable planning with default interval (3 steps)
      #   @return [AgentBuilder]
      #
      # @overload planning(interval_or_enabled)
      #   Enable planning with specific interval or toggle
      #   @param interval_or_enabled [Integer, Boolean, Symbol] Interval, true/:enabled, or false/:disabled
      #   @return [AgentBuilder]
      #
      # @overload planning(interval:, templates:)
      #   Full configuration with named parameters
      #   @param interval [Integer, nil] Steps between re-planning (default: 3)
      #   @param templates [Hash, nil] Custom planning prompt templates
      #   @return [AgentBuilder]
      #
      # @example Enable with defaults
      #   .planning                      # interval: 3 (research-backed default)
      #
      # @example Enable with custom interval
      #   .planning(5)                   # re-plan every 5 steps
      #
      # @example Explicit enable/disable
      #   .planning(true)                # same as .planning
      #   .planning(false)               # disable planning
      #   .planning(:enabled)            # same as .planning
      #   .planning(:disabled)           # disable planning
      #
      # @example Full configuration
      #   .planning(interval: 3, templates: { initial_plan: "..." })
      #
      def planning(interval_or_enabled = :_default_, interval: nil, templates: nil)
        check_frozen!

        resolved_interval = resolve_planning_interval(interval_or_enabled, interval)

        with_config(
          planning_interval: resolved_interval,
          planning_templates: templates || configuration[:planning_templates]
        )
      end

      # Configure memory management.
      #
      # @overload memory
      #   Use default config (no budget, :full strategy)
      # @overload memory(budget:)
      #   Set token budget with mask strategy
      # @overload memory(budget:, strategy:, preserve_recent:)
      #   Full configuration
      #
      # @param budget [Integer, nil] Token budget for memory
      # @param strategy [Symbol, nil] Memory strategy (:full, :mask, :summarize, :hybrid)
      # @param preserve_recent [Integer, nil] Number of recent steps to preserve
      # @return [AgentBuilder]
      #
      # @example Use defaults
      #   .memory
      #
      # @example Set budget with mask strategy
      #   .memory(budget: 100_000)
      #
      # @example Full configuration
      #   .memory(budget: 100_000, strategy: :hybrid, preserve_recent: 5)
      def memory(budget: nil, strategy: nil, preserve_recent: nil)
        check_frozen!
        with_config(memory_config: build_memory_config(budget, strategy, preserve_recent))
      end

      private

      def build_memory_config(budget, strategy, preserve_recent)
        return Types::MemoryConfig.default if budget.nil? && strategy.nil?

        Types::MemoryConfig.new(
          budget:,
          strategy: strategy || (budget ? :mask : :full),
          preserve_recent: preserve_recent || 5,
          mask_placeholder: "[Previous observation truncated]"
        )
      end

      def resolve_planning_interval(positional, named)
        return named if named

        case positional
        when :_default_, true, :enabled, :on then Config::DEFAULT_PLANNING_INTERVAL
        when Integer then positional
        when false, :disabled, :off, nil then nil
        else
          raise ArgumentError, "Invalid planning argument: #{positional.inspect}. " \
                               "Use Integer, true/false, :enabled/:disabled, or interval: keyword."
        end
      end

      public

      # @param count [Integer] Maximum steps (1-1000)
      # @return [AgentBuilder]
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # @param text [String] Custom instructions
      # @return [AgentBuilder]
      def instructions(text)
        check_frozen!
        validate!(:instructions, text)
        current = configuration[:custom_instructions]
        merged = current ? "#{current}\n\n#{text}" : text
        with_config(custom_instructions: merged)
      end

      # Apply a persona (behavioral instructions).
      #
      # @param name [Symbol] Persona name from Personas module
      # @return [AgentBuilder]
      #
      # @example
      #   Smolagents.agent.as(:researcher)
      def as(name)
        check_frozen!
        persona_text = Personas.get(name)
        raise ArgumentError, "Unknown persona: #{name}. Available: #{Personas.names.join(", ")}" unless persona_text

        instructions(persona_text)
      end

      # Configure agent's ability to spawn child agents.
      #
      # @param allow [Array<Symbol>] Model roles children can use (empty = any registered)
      # @param tools [Array<Symbol>] Tools available to children (default: [:final_answer])
      # @param inherit [Symbol] Context inheritance (:task_only, :observations, :summary, :full)
      # @param max_children [Integer] Maximum spawned agents (default: 3)
      # @return [AgentBuilder]
      #
      # @example
      #   .can_spawn(allow: [:researcher, :fast], tools: [:search, :final_answer], inherit: :observations)
      def can_spawn(allow: [], tools: [:final_answer], inherit: :task_only, max_children: 3)
        check_frozen!

        spawn_config = Types::SpawnConfig.create(allow:, tools:, inherit:, max_children:)
        with_config(spawn_config:)
      end

      # @param executor [Executor] Code execution environment
      # @return [AgentBuilder]
      def executor(executor) = with_config(executor:)

      # @param imports [Array<String>] Authorized Ruby libraries
      # @return [AgentBuilder]
      def authorized_imports(*imports) = with_config(authorized_imports: imports.flatten)

      # @param logger [Logger] Custom logger
      # @return [AgentBuilder]
      def logger(logger) = with_config(logger:)

      # Add a managed sub-agent.
      # @param agent_or_builder [Agent, AgentBuilder] Sub-agent
      # @param as [String, Symbol] Name for the sub-agent
      # @return [AgentBuilder]
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with_config(managed_agents: configuration[:managed_agents].merge(as.to_s => resolved))
      end

      # Build the configured agent.
      # @return [Agents::Agent]
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
        managed = cfg[:managed_agents].empty? ? nil : cfg[:managed_agents]
        {
          model: resolve_model, tools: resolve_tools, max_steps: cfg[:max_steps],
          planning_interval: cfg[:planning_interval], planning_templates: cfg[:planning_templates],
          custom_instructions: cfg[:custom_instructions], managed_agents: managed, logger: cfg[:logger],
          executor: cfg[:executor], authorized_imports: cfg[:authorized_imports],
          memory_config: cfg[:memory_config], spawn_config: cfg[:spawn_config]
        }.compact
      end

      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
      end

      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless configuration[:model_block]

        configuration[:model_block].call
      end

      def resolve_tools
        registry_tools = configuration[:tool_names].map do |name|
          Tools.get(name.to_s) || raise(ArgumentError, "Unknown tool: #{name}. Available: #{Tools.names.join(", ")}")
        end
        registry_tools + configuration[:tool_instances]
      end

      def partition_tool_args(args)
        args.partition { |t| t.is_a?(Symbol) || t.is_a?(String) }
      end

      def expand_toolkits(names)
        names.flat_map { |n| Toolkits.toolkit?(n.to_sym) ? Toolkits.get(n.to_sym) : [n.to_sym] }
      end

      def collect_specializations(names)
        result = { tools: [], instructions: [] }
        names.each { |name| process_specialization_name(name, result) }
        result
      end

      def process_specialization_name(name, result)
        spec = Specializations.get(name)
        unless spec
          raise ArgumentError,
                "Unknown specialization: #{name}. Available: #{Specializations.names.join(", ")}"
        end

        result[:tools].concat(spec.tools)
        result[:instructions] << spec.instructions if spec.instructions
      end

      def build_with_specializations(collected)
        updated_instructions = merge_instructions(collected[:instructions])
        self.class.new(
          configuration: configuration.merge(
            tool_names: (configuration[:tool_names] + collected[:tools]).uniq,
            custom_instructions: updated_instructions
          )
        )
      end

      def merge_instructions(new_instructions)
        merged = [configuration[:custom_instructions], *new_instructions].compact.join("\n\n")
        merged.empty? ? nil : merged
      end
    end
  end
end
