# frozen_string_literal: true

module Smolagents
  # Domain-Specific Language for building agents declaratively.
  # Provides a Ruby-native way to define agents, tools, and workflows.
  #
  # @example Simple agent definition
  #   agent = Smolagents.define_agent do
  #     name "Research Assistant"
  #     description "Helps with research tasks"
  #
  #     use_model "gpt-4"
  #     max_steps 10
  #
  #     tool :web_search do
  #       description "Search the web"
  #       input :query, type: :string
  #
  #       execute do |query:|
  #         # Search implementation
  #       end
  #     end
  #
  #     on :step_complete do |step_name, monitor|
  #       puts "Completed: #{step_name} in #{monitor.duration}s"
  #     end
  #   end
  #
  # @example Tool-only definition
  #   search_tool = Smolagents.define_tool(:search) do
  #     description "Search for information"
  #     input :query, type: :string, description: "Search query"
  #     output_type :string
  #
  #     execute do |query:|
  #       perform_search(query)
  #     end
  #   end
  module DSL
    # Define a new agent using DSL.
    #
    # @yield [builder] DSL builder block
    # @return [MultiStepAgent] configured agent
    #
    # @example
    #   agent = Smolagents.define_agent do
    #     use_model "gpt-4"
    #     tool :search
    #     max_steps 5
    #   end
    def self.define_agent(&)
      builder = AgentBuilder.new
      builder.instance_eval(&)
      builder.build
    end

    # Define a new tool using DSL.
    #
    # @param name [Symbol, String] tool name
    # @yield [builder] DSL builder block
    # @return [Tool] configured tool
    #
    # @example
    #   tool = Smolagents.define_tool(:calculator) do
    #     description "Perform calculations"
    #     input :expression, type: :string
    #     output_type :number
    #
    #     execute do |expression:|
    #       eval(expression)
    #     end
    #   end
    def self.define_tool(name, &)
      builder = ToolBuilder.new(name)
      builder.instance_eval(&)
      builder.build
    end

    # Agent builder DSL.
    class AgentBuilder
      def initialize
        @name = nil
        @description = nil
        @model = nil
        @tools = []
        @max_steps = Smolagents.configuration.max_steps
        @callbacks = {}
        @agent_type = :code # :code or :tool_calling
      end

      # Set agent name.
      #
      # @param name [String] agent name
      def name(name)
        @name = name
      end

      # Set agent description.
      #
      # @param desc [String] description
      def description(desc)
        @description = desc
      end

      # Set the model to use.
      #
      # @param model_id [String, Model] model ID or model instance
      # @param api_key [String, nil] optional API key
      # @param provider [Symbol] :openai, :anthropic, etc.
      def use_model(model_id, api_key: nil, provider: :openai)
        @model = if model_id.is_a?(Model)
                   model_id
                 else
                   build_model(model_id, api_key: api_key, provider: provider)
                 end
      end

      # Set agent type.
      #
      # @param type [Symbol] :code or :tool_calling
      def agent_type(type)
        @agent_type = type
      end

      # Add a tool to the agent.
      #
      # @param tool [Symbol, Tool] tool name or instance
      # @yield [builder] optional tool definition block
      def tool(tool = nil, &)
        if block_given?
          @tools << DSL.define_tool(tool, &)
        elsif tool.is_a?(Tool)
          @tools << tool
        elsif tool.is_a?(Symbol) || tool.is_a?(String)
          # Load from default tools
          @tools << load_default_tool(tool)
        end
      end

      # Add multiple tools at once.
      #
      # @param tool_names [Array<Symbol>] tool names
      def tools(*tool_names)
        tool_names.each { |name| tool(name) }
      end

      # Set max steps.
      #
      # @param steps [Integer] maximum steps
      def max_steps(steps)
        @max_steps = steps
      end

      # Register a callback.
      #
      # @param event [Symbol] event name
      # @yield callback block
      def on(event, &block)
        @callbacks[event] ||= []
        @callbacks[event] << block
      end

      # Build the agent.
      #
      # @return [MultiStepAgent]
      def build
        raise ArgumentError, "Model is required" unless @model
        raise ArgumentError, "At least one tool is required" if @tools.empty?

        agent_class = case @agent_type
                      when :code
                        CodeAgent
                      when :tool_calling
                        ToolCallingAgent
                      else
                        raise ArgumentError, "Unknown agent type: #{@agent_type}"
                      end

        agent = agent_class.new(
          model: @model,
          tools: @tools,
          max_steps: @max_steps
        )

        # Register callbacks
        @callbacks.each do |event, callbacks|
          callbacks.each { |callback| agent.register_callback(event, &callback) }
        end

        agent
      end

      private

      def build_model(model_id, api_key:, provider:)
        case provider
        when :openai
          require_relative "models/openai_model" unless defined?(OpenAIModel)
          OpenAIModel.new(model_id: model_id, api_key: api_key)
        when :anthropic
          require_relative "models/anthropic_model" unless defined?(AnthropicModel)
          AnthropicModel.new(model_id: model_id, api_key: api_key)
        else
          raise ArgumentError, "Unknown provider: #{provider}"
        end
      end

      def load_default_tool(name)
        require_relative "default_tools" unless defined?(DefaultTools)
        DefaultTools.get(name.to_s) || raise(ArgumentError, "Unknown tool: #{name}")
      end
    end

    # Tool builder DSL.
    class ToolBuilder
      def initialize(name)
        @name = name.to_s
        @description = nil
        @inputs = {}
        @output_type = "any"
        @output_schema = nil
        @execute_block = nil
      end

      # Set tool description.
      #
      # @param desc [String] description
      def description(desc)
        @description = desc
      end

      # Define an input parameter.
      #
      # @param name [Symbol] parameter name
      # @param type [Symbol, String] parameter type
      # @param description [String] parameter description
      # @param nullable [Boolean] whether parameter is optional
      def input(name, type:, description: nil, nullable: false)
        @inputs[name.to_s] = {
          "type" => type.to_s,
          "description" => description || "Input parameter #{name}",
          "nullable" => nullable
        }
      end

      # Define multiple inputs at once.
      #
      # @param specs [Hash] input specifications
      #
      # @example
      #   inputs(
      #     query: { type: :string, description: "Query" },
      #     limit: { type: :integer, nullable: true }
      #   )
      def inputs(**specs)
        specs.each do |name, spec|
          input(name, **spec)
        end
      end

      # Set output type.
      #
      # @param type [Symbol, String] output type
      def output_type(type)
        @output_type = type.to_s
      end

      # Set output schema for structured outputs.
      #
      # @param schema [Hash] JSON schema
      def output_schema(schema)
        @output_schema = schema
      end

      # Define the execution logic.
      #
      # @yield tool execution block
      def execute(&block)
        @execute_block = block
      end

      # Build the tool.
      #
      # @return [Tool]
      def build
        raise ArgumentError, "Description is required" unless @description
        raise ArgumentError, "Execute block is required" unless @execute_block

        # Capture instance variables for use in class block
        name = @name
        description = @description
        inputs = @inputs
        output_type = @output_type
        output_schema = @output_schema
        execute_block = @execute_block

        tool_class = Class.new(Tool) do
          self.tool_name = name
          self.description = description
          self.inputs = inputs
          self.output_type = output_type
          self.output_schema = output_schema

          define_method(:forward, &execute_block)
        end

        tool_class.new
      end
    end
  end

  # Convenience methods at module level.
  class << self
    # Define an agent using DSL.
    #
    # @see DSL.define_agent
    def define_agent(&)
      DSL.define_agent(&)
    end

    # Define a tool using DSL.
    #
    # @see DSL.define_tool
    def define_tool(name, &)
      DSL.define_tool(name, &)
    end

    # Quick agent creation with defaults.
    #
    # @param model [String, Model] model to use
    # @param tools [Array<Symbol, Tool>] tools to include
    # @return [CodeAgent] simple code agent
    #
    # @example
    #   agent = Smolagents.agent(
    #     model: "gpt-4",
    #     tools: [:web_search, :final_answer]
    #   )
    #   result = agent.run("Search for Ruby news")
    def agent(model:, tools: [], **kwargs)
      DSL.define_agent do
        use_model(model)
        tools(*tools)
        kwargs.each { |k, v| send(k, v) if respond_to?(k) }
      end
    end
  end
end
