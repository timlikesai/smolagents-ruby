module Smolagents
  module Builders
    # Chainable builder for configuring agents.
    #
    # Agents are built from composable atoms:
    # - **Mode**: `.with(:code)` for code-writing, default is tool-calling
    # - **Tools**: `.tools(:search, :visit)` or `.tools(*Toolkits::SEARCH)`
    # - **Persona**: `.as(:researcher)` for behavioral instructions
    #
    # @example Basic tool-calling agent
    #   Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @example Code-writing agent with tools
    #   Smolagents.agent
    #     .with(:code)
    #     .tools(*Toolkits::SEARCH, *Toolkits::DATA)
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @example Agent with persona
    #   Smolagents.agent
    #     .tools(*Toolkits::RESEARCH)
    #     .as(:researcher)
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @example Convenience specialization (combines tools + persona)
    #   Smolagents.agent
    #     .with(:researcher)  # expands to tools + persona
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    AgentBuilder = Data.define(:agent_type, :configuration) do
      include Base
      include EventHandlers

      define_handler :tool, maps_to: :tool_complete

      def self.default_configuration
        { model_block: nil, tool_names: [], tool_instances: [], planning_interval: nil, planning_templates: nil,
          max_steps: nil, custom_instructions: nil, executor: nil, authorized_imports: nil, managed_agents: {},
          handlers: [], logger: nil }
      end

      # @param agent_type [Symbol] :code or :tool
      # @return [AgentBuilder]
      def self.create(agent_type)
        new(agent_type: agent_type.to_sym, configuration: default_configuration)
      end

      register_method :model, description: "Set model (required)", required: true
      register_method :max_steps, description: "Set max steps (1-1000)",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 1000 }
      register_method :planning, description: "Configure planning interval"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :with, description: "Add mode (:code) or specialization"

      # Set model via block (deferred evaluation).
      # @yield Block returning a Model instance
      # @return [AgentBuilder]
      def model(&block)
        check_frozen!
        raise ArgumentError, "Model block required" unless block

        with_config(model_block: block)
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

      # Add execution mode or convenience specialization.
      #
      # **Modes**: `:code` for code-writing (default is tool-calling)
      # **Specializations**: `:researcher`, `:fact_checker`, `:data_analyst`, etc.
      #
      # For finer control, use `.tools()` and `.as()` separately.
      #
      # @param names [Array<Symbol>] Mode or specialization names
      # @return [AgentBuilder]
      def with(*names)
        check_frozen!
        names = names.flatten.map(&:to_sym)
        return self if names.empty?

        collected = collect_specializations(names)
        build_with_specializations(collected)
      end

      # Configure planning.
      # @param interval [Integer, nil] Steps between planning
      # @param templates [Hash, nil] Custom planning templates
      # @return [AgentBuilder]
      def planning(interval: nil, templates: nil)
        with_config(
          planning_interval: interval || configuration[:planning_interval],
          planning_templates: templates || configuration[:planning_templates]
        )
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

      # Apply a persona (behavioral instructions).
      #
      # Personas define HOW an agent approaches tasks. They're just
      # instruction templates - no tool coupling, no mode changes.
      #
      # @param name [Symbol] Persona name from Personas module
      # @return [AgentBuilder]
      #
      # @example
      #   Smolagents.agent.as(:researcher)
      #   Smolagents.agent.as(:analyst)
      def as(name)
        check_frozen!
        persona_text = Personas.get(name)
        raise ArgumentError, "Unknown persona: #{name}. Available: #{Personas.names.join(", ")}" unless persona_text

        instructions(persona_text)
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
      # @return [Agent] CodeAgent or ToolAgent
      def build
        agent_class = resolve_agent_class
        agent = agent_class.new(**build_agent_args)
        configuration[:handlers].each { |event_type, block| agent.on(event_type, &block) }
        agent
      end

      def config = configuration.dup

      def inspect
        tools_desc = (configuration[:tool_names] + configuration[:tool_instances].map do |t|
          t.name || t.class.name
        end).join(", ")
        "#<AgentBuilder type=#{agent_type} tools=[#{tools_desc}] handlers=#{configuration[:handlers].size}>"
      end

      private

      def resolve_agent_class
        class_name = Builders::AGENT_TYPES.fetch(agent_type) do
          raise ArgumentError, "Unknown agent type: #{agent_type}. Valid: #{Builders::AGENT_TYPES.keys.join(", ")}"
        end
        Object.const_get(class_name)
      end

      def build_agent_args
        cfg = configuration
        managed = cfg[:managed_agents].empty? ? nil : cfg[:managed_agents]
        args = {
          model: resolve_model, tools: resolve_tools, max_steps: cfg[:max_steps],
          planning_interval: cfg[:planning_interval], planning_templates: cfg[:planning_templates],
          custom_instructions: cfg[:custom_instructions], managed_agents: managed, logger: cfg[:logger]
        }.compact
        args.merge!(code_agent_args) if agent_type == :code
        args
      end

      def code_agent_args
        { executor: configuration[:executor], authorized_imports: configuration[:authorized_imports] }.compact
      end

      def with_config(**kwargs)
        self.class.new(agent_type:, configuration: configuration.merge(kwargs))
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
        result = { tools: [], instructions: [], needs_code: agent_type == :code }
        names.each { |name| process_specialization_name(name, result) }
        result
      end

      def process_specialization_name(name, result)
        if name == :code
          result[:needs_code] = true
          return
        end
        spec = Specializations.get(name)
        raise ArgumentError, "Unknown: #{name}. Modes: [:code]. Specs: #{Specializations.names.join(", ")}" unless spec

        result[:tools].concat(spec.tools)
        result[:instructions] << spec.instructions if spec.instructions
        result[:needs_code] = true if spec.needs_code?
      end

      def build_with_specializations(collected)
        updated_instructions = merge_instructions(collected[:instructions])
        self.class.new(
          agent_type: collected[:needs_code] ? :code : agent_type,
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
