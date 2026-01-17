require_relative "execution_concern"
require_relative "inline_tool_concern"
require_relative "memory_concern"
require_relative "planning_concern"
require_relative "spawn_concern"
require_relative "specialization_concern"
require_relative "tool_resolution"

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
      register_method :max_steps, description: "Set max steps (1-1000)",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }
      register_method :planning, description: "Configure planning interval"
      register_method :memory, description: "Configure memory management (budget, strategy)"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :with, description: "Add specialization"
      register_method :can_spawn, description: "Configure spawn capability"
      register_method :evaluation, description: "Enable structured evaluation phase"

      # Set model via block or registered name.
      #
      # Blocks enable **lazy instantiation** - the model isn't created until
      # `.build` is called. This defers connection setup, API key validation,
      # and resource allocation until the agent is actually needed.
      #
      # @overload model { ... }
      #   Set model via block (recommended). The block is called at build time.
      #   @example Lazy instantiation (model created at build time)
      #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
      #   @example Capturing an existing model (still uses block for consistency)
      #     my_model = OpenAIModel.lm_studio("gemma-3n-e4b")
      #     .model { my_model }
      #
      # @overload model(:registered_name)
      #   Reference a model registered in configuration. Also lazy - the
      #   registered factory is called at build time.
      #   @example Register then use by name
      #     Smolagents.configure do |c|
      #       c.models { |m| m.register(:local, -> { OpenAIModel.lm_studio("gemma") }) }
      #     end
      #     agent = Smolagents.agent.model(:local).build
      #
      # @return [AgentBuilder]
      # @raise [ArgumentError] If neither name nor block provided
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

      # @param executor [Executor] Code execution environment
      # @return [AgentBuilder]
      def executor(executor) = with_config(executor:)

      # @param imports [Array<String>] Authorized Ruby libraries
      # @return [AgentBuilder]
      def authorized_imports(*imports) = with_config(authorized_imports: imports.flatten)

      # @param logger [Logger] Custom logger
      # @return [AgentBuilder]
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
      # @return [AgentBuilder]
      #
      # @example Disable evaluation (not recommended)
      #   Smolagents.agent
      #     .model { my_model }
      #     .evaluation(enabled: false)
      #     .build
      def evaluation(enabled: true)
        check_frozen!
        with_config(evaluation_enabled: enabled)
      end

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
          memory_config: cfg[:memory_config], spawn_config: cfg[:spawn_config],
          evaluation_enabled: cfg[:evaluation_enabled]
        }.compact
      end

      def with_config(**kwargs)
        self.class.new(configuration: configuration.merge(kwargs))
      end

      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless configuration[:model_block]

        configuration[:model_block].call
      end
    end
  end
end
