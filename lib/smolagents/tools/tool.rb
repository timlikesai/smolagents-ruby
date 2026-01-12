require "forwardable"

module Smolagents
  class Tool
    extend Forwardable

    AUTHORIZED_TYPES = Set.new(%w[string boolean integer number image audio array object any null]).freeze

    class << self
      attr_accessor :tool_name, :description, :output_type, :output_schema
      attr_reader :inputs

      def inputs=(value)
        @inputs = deep_symbolize_keys(value)
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@tool_name, nil)
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@inputs, {})
        subclass.instance_variable_set(:@output_type, "any")
        subclass.instance_variable_set(:@output_schema, nil)
      end

      private

      def deep_symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.transform_keys(&:to_sym).transform_values do |value|
          value.is_a?(Hash) ? deep_symbolize_keys(value) : value
        end
      end
    end

    def_delegators :"self.class", :tool_name, :description, :inputs, :output_type, :output_schema
    alias name tool_name

    def initialize
      @initialized = false
      validate_arguments!
    end

    def initialized? = @initialized

    def call(*args, sanitize_inputs_outputs: false, wrap_result: true, **kwargs)
      Instrumentation.instrument("smolagents.tool.call", tool_name: name, tool_class: self.class.name) do
        setup unless @initialized
        kwargs = args.first if args.length == 1 && kwargs.empty? && args.first.is_a?(Hash)
        result = forward(**kwargs)
        wrap_result ? wrap_in_tool_result(result, kwargs) : result
      end
    end

    def forward(**_kwargs) = raise(NotImplementedError, "#{self.class}#forward must be implemented")
    def setup = @initialized = true

    def to_code_prompt
      args_sig = inputs.map { |n, s| "#{n}: #{s[:type]}" }.join(", ")
      doc = inputs.any? ? "#{description}\n\nArgs:\n#{inputs.map { |n, s| "  #{n}: #{s[:description]}" }.join("\n")}" : description
      doc += "\n\nReturns:\n  Hash (structured output): #{output_schema}" if output_schema
      "def #{name}(#{args_sig}) -> #{output_schema ? "Hash" : output_type}\n  \"\"\"\n  #{doc}\n  \"\"\"\nend\n"
    end

    def to_tool_calling_prompt = "#{name}: #{description}\n  Takes inputs: #{inputs}\n  Returns an output of type: #{output_type}\n"
    def to_h = { name: name, description: description, inputs: inputs, output_type: output_type, output_schema: output_schema }.compact

    def validate_arguments!
      raise ArgumentError, "Tool must have a name" unless name
      raise ArgumentError, "Tool must have a description" unless description
      raise ArgumentError, "Tool inputs must be a Hash" unless inputs.is_a?(Hash)
      raise ArgumentError, "Tool must have an output_type" unless output_type
      raise ArgumentError, "Invalid output_type: #{output_type}" unless AUTHORIZED_TYPES.include?(output_type)

      inputs.each do |input_name, spec|
        raise ArgumentError, "Input '#{input_name}' must be a Hash" unless spec.is_a?(Hash)
        raise ArgumentError, "Input '#{input_name}' must have type" unless spec.key?(:type)
        raise ArgumentError, "Input '#{input_name}' must have description" unless spec.key?(:description)

        Array(spec[:type]).each { |t| raise ArgumentError, "Invalid type '#{t}' for input '#{input_name}'" unless AUTHORIZED_TYPES.include?(t) }
      end
    end

    def validate_tool_arguments(arguments)
      raise AgentToolCallError, "Tool '#{name}' expects Hash arguments, got #{arguments.class}" unless arguments.is_a?(Hash)

      inputs.each do |input_name, spec|
        next if spec[:nullable]
        raise AgentToolCallError, "Tool '#{name}' missing required input: #{input_name}" unless arguments.key?(input_name) || arguments.key?(input_name.to_sym)
      end
      valid_keys = inputs.keys.flat_map { |k| [k, k.to_sym] }
      arguments.each_key { |k| raise AgentToolCallError, "Tool '#{name}' received unexpected input: #{k}" unless valid_keys.include?(k) }
    end

    private

    def wrap_in_tool_result(result, inputs)
      return result if result.is_a?(ToolResult)

      metadata = { inputs: inputs, output_type: output_type }
      if result.is_a?(String) && result.start_with?("Error", "An unexpected error")
        ToolResult.error(StandardError.new(result), tool_name: name, metadata: metadata)
      else
        ToolResult.new(result, tool_name: name, metadata: metadata)
      end
    end
  end
end
