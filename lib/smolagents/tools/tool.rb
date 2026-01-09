# frozen_string_literal: true

require "forwardable"

module Smolagents
  # Base class for tools that agents can use.
  # Tools are callable objects that perform specific actions.
  #
  # @example Creating a custom tool
  #   class MyTool < Tool
  #     self.tool_name = "my_tool"
  #     self.description = "Does something useful"
  #     self.inputs = {
  #       "param" => { "type" => "string", "description" => "A parameter" }
  #     }
  #     self.output_type = "string"
  #
  #     def forward(param:)
  #       "Processed: #{param}"
  #     end
  #   end
  class Tool
    extend Forwardable

    # Class-level attributes for tool metadata
    class << self
      attr_accessor :tool_name, :description, :inputs, :output_type, :output_schema

      def inherited(subclass)
        super
        # Initialize class attributes for subclass
        subclass.instance_variable_set(:@tool_name, nil)
        subclass.instance_variable_set(:@description, nil)
        subclass.instance_variable_set(:@inputs, {})
        subclass.instance_variable_set(:@output_type, "any")
        subclass.instance_variable_set(:@output_schema, nil)
      end
    end

    # Authorized output types (using Set for O(1) lookups)
    AUTHORIZED_TYPES = Set.new(%w[
                                 string boolean integer number image audio array object any null
                               ]).freeze

    # Delegate to class attributes using Forwardable
    def_delegators :"self.class", :tool_name, :description, :inputs, :output_type, :output_schema

    # Alias for cleaner API
    alias name tool_name

    def initialize
      @initialized = false
      validate_arguments!
    end

    # Check if tool has been initialized.
    # @return [Boolean]
    def initialized?
      @initialized
    end

    # Call the tool (main entry point).
    # @param args [Array] positional arguments
    # @param sanitize_inputs_outputs [Boolean] whether to sanitize inputs/outputs
    # @param kwargs [Hash] keyword arguments
    # @return [Object] tool result
    def call(*args, sanitize_inputs_outputs: false, **kwargs)
      setup unless @initialized

      # Handle single hash argument
      if args.length == 1 && kwargs.empty? && args.first.is_a?(Hash)
        kwargs = args.first
        args = []
      end

      forward(*args, **kwargs)
    end

    # Execute the tool (must be implemented by subclasses).
    # @abstract
    # @return [Object] tool result
    def forward(*_args, **_kwargs)
      raise NotImplementedError, "#{self.class}#forward must be implemented"
    end

    # Setup hook for lazy initialization (override if needed).
    def setup
      @initialized = true
    end

    # Generate code-style prompt for this tool.
    # @return [String]
    def to_code_prompt
      args_sig = inputs.map { |name, schema| "#{name}: #{schema["type"]}" }.join(", ")
      ret_type = output_schema ? "Hash" : output_type

      doc = description.dup
      if inputs.any?
        args_doc = inputs.map do |name, schema|
          "  #{name}: #{schema["description"]}"
        end.join("\n")
        doc += "\n\nArgs:\n#{args_doc}"
      end

      doc += "\n\nReturns:\n  Hash (structured output): #{output_schema}" if output_schema

      <<~RUBY
        def #{name}(#{args_sig}) -> #{ret_type}
          """
          #{doc}
          """
        end
      RUBY
    end

    # Generate tool-calling style prompt for this tool.
    # @return [String]
    def to_tool_calling_prompt
      <<~TEXT
        #{name}: #{description}
          Takes inputs: #{inputs}
          Returns an output of type: #{output_type}
      TEXT
    end

    # Convert tool to hash representation.
    # @return [Hash]
    def to_h
      {
        name: name,
        description: description,
        inputs: inputs,
        output_type: output_type,
        output_schema: output_schema
      }.compact
    end

    # Validate tool attributes and configuration.
    def validate_arguments!
      raise ArgumentError, "Tool must have a name" unless name
      raise ArgumentError, "Tool must have a description" unless description
      raise ArgumentError, "Tool inputs must be a Hash" unless inputs.is_a?(Hash)
      raise ArgumentError, "Tool must have an output_type" unless output_type

      # Validate output type
      raise ArgumentError, "Invalid output_type: #{output_type}. Must be one of: #{AUTHORIZED_TYPES.join(", ")}" unless AUTHORIZED_TYPES.include?(output_type)

      # Validate each input
      inputs.each do |input_name, input_spec|
        raise ArgumentError, "Input '#{input_name}' must be a Hash, got #{input_spec.class}" unless input_spec.is_a?(Hash)

        raise ArgumentError, "Input '#{input_name}' must have a 'type' key" unless input_spec.key?("type")

        raise ArgumentError, "Input '#{input_name}' must have a 'description' key" unless input_spec.key?("description")

        input_type = input_spec["type"]
        types = input_type.is_a?(Array) ? input_type : [input_type]
        types.each do |t|
          raise ArgumentError, "Invalid type '#{t}' for input '#{input_name}'" unless AUTHORIZED_TYPES.include?(t)
        end
      end
    end

    # Validate tool call arguments against input schema.
    # @param arguments [Hash] the arguments to validate
    # @raise [AgentToolCallError] if validation fails
    def validate_tool_arguments(arguments)
      raise AgentToolCallError, "Tool '#{name}' expects Hash arguments, got #{arguments.class}" unless arguments.is_a?(Hash)

      # Check required inputs
      inputs.each do |input_name, input_spec|
        is_optional = input_spec["nullable"] == true
        next if is_optional

        raise AgentToolCallError, "Tool '#{name}' missing required input: #{input_name}" unless arguments.key?(input_name) || arguments.key?(input_name.to_sym)
      end

      # Check for unexpected inputs
      valid_keys = inputs.keys.map { |k| [k, k.to_sym] }.flatten
      arguments.each_key do |key|
        raise AgentToolCallError, "Tool '#{name}' received unexpected input: #{key}" unless valid_keys.include?(key)
      end
    end
  end
end
