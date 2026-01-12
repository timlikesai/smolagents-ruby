module Smolagents
  module Builders
    # Chainable builder for configuring and creating agents.
    #
    # @example Basic usage
    #   agent = Smolagents.agent(:code)
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .tools(:google_search, :visit_webpage)
    #     .max_steps(10)
    #     .build
    #
    # @example With planning and callbacks
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { AnthropicModel.new(model_id: "claude-3") }
    #     .tools(:search, custom_tool)
    #     .planning(interval: 3)
    #     .on(:step_complete) { |step| puts step }
    #     .on(:task_complete) { |result| log(result) }
    #     .build
    #
    class AgentBuilder
      AGENT_TYPES = {
        code: Agents::Code,
        tool_calling: Agents::ToolCalling
      }.freeze

      attr_reader :agent_type, :config

      def initialize(agent_type, config = {})
        @agent_type = agent_type.to_sym
        @config = {
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
          callbacks: [],
          logger: nil
        }.merge(config).freeze
      end

      # Set the model via a block (deferred evaluation)
      #
      # @yield Block that returns a Model instance
      # @return [AgentBuilder] New builder with model configured
      def model(&block)
        with(model_block: block)
      end

      # Add tools by name (from registry) or instance
      #
      # @param names_or_instances [Array<Symbol, String, Tool>] Tools to add
      # @return [AgentBuilder] New builder with tools added
      def tools(*names_or_instances)
        names, instances = names_or_instances.flatten.partition do |t|
          t.is_a?(Symbol) || t.is_a?(String)
        end

        with(
          tool_names: config[:tool_names] + names.map(&:to_sym),
          tool_instances: config[:tool_instances] + instances
        )
      end

      # Configure planning
      #
      # @param interval [Integer] Steps between planning updates
      # @param templates [Hash] Custom planning templates
      # @return [AgentBuilder] New builder with planning configured
      def planning(interval: nil, templates: nil)
        with(
          planning_interval: interval || config[:planning_interval],
          planning_templates: templates || config[:planning_templates]
        )
      end

      # Set maximum steps
      #
      # @param n [Integer] Maximum number of steps
      # @return [AgentBuilder] New builder with max_steps set
      def max_steps(n)
        with(max_steps: n)
      end

      # Set custom instructions
      #
      # @param text [String] Custom instructions for the agent
      # @return [AgentBuilder] New builder with instructions set
      def instructions(text)
        with(custom_instructions: text)
      end

      # Set executor (for code agents)
      #
      # @param executor [Executor] Custom executor instance
      # @return [AgentBuilder] New builder with executor set
      def executor(executor)
        with(executor: executor)
      end

      # Set authorized imports (for code agents)
      #
      # @param imports [Array<String>] Authorized import list
      # @return [AgentBuilder] New builder with imports set
      def authorized_imports(*imports)
        with(authorized_imports: imports.flatten)
      end

      # Set logger
      #
      # @param logger [AgentLogger] Logger instance
      # @return [AgentBuilder] New builder with logger set
      def logger(logger)
        with(logger: logger)
      end

      # Register a callback for an event
      #
      # @param event [Symbol] Event name (e.g., :step_complete, :task_complete)
      # @yield Block to call when event fires
      # @return [AgentBuilder] New builder with callback added
      def on(event, &block)
        with(callbacks: config[:callbacks] + [[event, block]])
      end

      # Add a managed sub-agent
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for the managed agent
      # @return [AgentBuilder] New builder with managed agent added
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with(managed_agents: config[:managed_agents].merge(as.to_s => resolved))
      end

      # Build the configured agent
      #
      # @return [Agent] Configured agent instance
      # @raise [ArgumentError] If model not configured
      def build
        model_instance = resolve_model
        tools_array = resolve_tools

        agent_class = AGENT_TYPES.fetch(agent_type) do
          raise ArgumentError, "Unknown agent type: #{agent_type}. Valid types: #{AGENT_TYPES.keys.join(", ")}"
        end

        agent_args = {
          model: model_instance,
          tools: tools_array,
          max_steps: config[:max_steps],
          planning_interval: config[:planning_interval],
          planning_templates: config[:planning_templates],
          custom_instructions: config[:custom_instructions],
          managed_agents: config[:managed_agents].empty? ? nil : config[:managed_agents],
          logger: config[:logger]
        }.compact

        # Add code-specific options
        if agent_type == :code
          agent_args[:executor] = config[:executor] if config[:executor]
          agent_args[:authorized_imports] = config[:authorized_imports] if config[:authorized_imports]
        end

        agent = agent_class.new(**agent_args)

        # Register callbacks
        config[:callbacks].each do |event, block|
          agent.register_callback(event, &block)
        end

        agent
      end

      # Inspect for debugging
      def inspect
        tools_desc = (config[:tool_names] + config[:tool_instances].map { |t| t.name || t.class.name }).join(", ")
        "#<AgentBuilder type=#{agent_type} tools=[#{tools_desc}] callbacks=#{config[:callbacks].size}>"
      end

      private

      def with(**changes)
        self.class.new(agent_type, config.merge(changes))
      end

      def resolve_model
        raise ArgumentError, "Model required. Use .model { YourModel.new(...) }" unless config[:model_block]

        config[:model_block].call
      end

      def resolve_tools
        # Resolve tools from registry by name
        registry_tools = config[:tool_names].map do |name|
          Tools.get(name.to_s) || raise(ArgumentError, "Unknown tool: #{name}. Available: #{Tools.names.join(", ")}")
        end

        # Combine with tool instances
        registry_tools + config[:tool_instances]
      end
    end
  end
end
