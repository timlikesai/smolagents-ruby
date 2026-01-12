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
        result = execute(**kwargs)
        wrap_result ? wrap_in_tool_result(result, kwargs) : result
      end
    end

    def execute(**_kwargs) = raise(NotImplementedError, "#{self.class}#execute must be implemented")
    def setup = @initialized = true

    def to_code_prompt
      args_sig = inputs.map { |name, spec| "#{name}: #{spec[:type]}" }.join(", ")
      doc = inputs.any? ? "#{description}\n\nArgs:\n#{inputs.map { |name, spec| "  #{name}: #{spec[:description]}" }.join("\n")}" : description
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

      inputs.each { |input_name, spec| validate_input_spec!(input_name, spec) }
    end

    def validate_arguments
      return false unless name && description && inputs.is_a?(Hash) && output_type
      return false unless AUTHORIZED_TYPES.include?(output_type)

      inputs.all? { |_, spec| validate_input_spec(spec) }
    end
    alias valid_arguments? validate_arguments

    def validate_input_spec!(input_name, spec)
      raise ArgumentError, "Input '#{input_name}' must be a Hash" unless spec.is_a?(Hash)
      raise ArgumentError, "Input '#{input_name}' must have type" unless spec.key?(:type)
      raise ArgumentError, "Input '#{input_name}' must have description" unless spec.key?(:description)

      Array(spec[:type]).each { |type| raise ArgumentError, "Invalid type '#{type}' for input '#{input_name}'" unless AUTHORIZED_TYPES.include?(type) }
    end

    def validate_input_spec(spec)
      spec.is_a?(Hash) && spec.key?(:type) && spec.key?(:description) &&
        Array(spec[:type]).all? { |type| AUTHORIZED_TYPES.include?(type) }
    end
    alias valid_input_spec? validate_input_spec

    def validate_tool_arguments(arguments)
      raise AgentToolCallError, "Tool '#{name}' expects Hash arguments, got #{arguments.class}" unless arguments.is_a?(Hash)

      inputs.each do |input_name, spec|
        next if spec[:nullable]
        raise AgentToolCallError, "Tool '#{name}' missing required input: #{input_name}" unless arguments.key?(input_name) || arguments.key?(input_name.to_sym)
      end
      valid_keys = inputs.keys.flat_map { |key| [key, key.to_sym] }
      arguments.each_key { |key| raise AgentToolCallError, "Tool '#{name}' received unexpected input: #{key}" unless valid_keys.include?(key) }
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
