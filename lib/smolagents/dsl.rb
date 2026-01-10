# frozen_string_literal: true

module Smolagents
  # Domain-Specific Language for building agents and tools declaratively.
  module DSL
    def self.define_agent(&) = AgentBuilder.new.tap { _1.instance_eval(&) }.build
    def self.define_tool(name, &) = ToolBuilder.new(name).tap { _1.instance_eval(&) }.build

    class AgentBuilder
      def initialize
        @model = nil
        @tools = []
        @max_steps = Smolagents.configuration.max_steps
        @callbacks = Hash.new { |h, k| h[k] = [] }
        @agent_type = :code
      end

      def name(name) = @name = name
      def description(desc) = @description = desc
      def agent_type(type) = @agent_type = type
      def max_steps(steps) = @max_steps = steps
      def on(event, &block) = @callbacks[event] << block

      def use_model(model_id, api_key: nil, provider: :openai)
        @model = model_id.is_a?(Model) ? model_id : build_model(model_id, api_key: api_key, provider: provider)
      end

      def tool(tool = nil, &block)
        @tools << (block ? DSL.define_tool(tool, &block) : (tool.is_a?(Tool) ? tool : load_default_tool(tool)))
      end

      def tools(*tool_names) = tool_names.each { |n| tool(n) }

      def build
        raise ArgumentError, "Model is required" unless @model
        raise ArgumentError, "At least one tool is required" if @tools.empty?
        agent = { code: CodeAgent, tool_calling: ToolCallingAgent }[@agent_type]&.new(model: @model, tools: @tools, max_steps: @max_steps) || raise(ArgumentError, "Unknown agent type: #{@agent_type}")
        @callbacks.each { |event, cbs| cbs.each { |cb| agent.register_callback(event, &cb) } }
        agent
      end

      private

      PROVIDERS = {
        openai: ->(id, key) { require_relative "models/openai_model"; OpenAIModel.new(model_id: id, api_key: key) },
        anthropic: ->(id, key) { require_relative "models/anthropic_model"; AnthropicModel.new(model_id: id, api_key: key) }
      }.freeze

      def build_model(model_id, api_key:, provider:) = PROVIDERS[provider]&.call(model_id, api_key) || raise(ArgumentError, "Unknown provider: #{provider}")

      def load_default_tool(name)
        require_relative "default_tools" unless defined?(DefaultTools)
        DefaultTools.get(name.to_s) || raise(ArgumentError, "Unknown tool: #{name}")
      end
    end

    class ToolBuilder
      def initialize(name)
        @name = name.to_s
        @description = nil
        @inputs = {}
        @output_type = "any"
        @output_schema = nil
        @execute_block = nil
      end

      def description(desc) = @description = desc
      def output_type(type) = @output_type = type.to_s
      def output_schema(schema) = @output_schema = schema
      def execute(&block) = @execute_block = block
      def input(name, type:, description: nil, nullable: false) = @inputs[name.to_s] = { "type" => type.to_s, "description" => description || "Input parameter #{name}", "nullable" => nullable }
      def inputs(**specs) = specs.each { |name, spec| input(name, **spec) }

      def build
        raise ArgumentError, "Description is required" unless @description
        raise ArgumentError, "Execute block is required" unless @execute_block
        name, desc, inputs, out_type, out_schema, exec = @name, @description, @inputs, @output_type, @output_schema, @execute_block
        Class.new(Tool) { self.tool_name = name; self.description = desc; self.inputs = inputs; self.output_type = out_type; self.output_schema = out_schema; define_method(:forward, &exec) }.new
      end
    end
  end

  class << self
    def define_agent(&) = DSL.define_agent(&)
    def define_tool(name, &) = DSL.define_tool(name, &)
    def agent(model:, tools: [], **kwargs) = DSL.define_agent { use_model(model); tools(*tools); kwargs.each { |k, v| send(k, v) if respond_to?(k) } }
  end
end
