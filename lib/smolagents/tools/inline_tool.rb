module Smolagents
  module Tools
    # Inline tool defined by a block - no class required.
    #
    # InlineTool inherits from Tool, gaining security validation and telemetry,
    # but stores configuration per-instance rather than per-class.
    #
    # @example Define inline in agent builder
    #   agent = Smolagents.agent
    #     .tool(:greet, "Generate a greeting", name: String) { |name:| "Hello, #{name}!" }
    #     .model { model }
    #     .build
    #
    # @example With multiple inputs
    #   agent = Smolagents.agent
    #     .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
    #     .model { model }
    #     .build
    #
    # @see AgentBuilder#tool Method that creates InlineTool instances
    # @see Tool Class-based tools for complex cases
    class InlineTool < Tool
      # Ruby type to JSON Schema type mapping.
      TYPE_MAP = {
        "String" => "string", "Integer" => "integer", "Float" => "number",
        "TrueClass" => "boolean", "FalseClass" => "boolean",
        "Array" => "array", "Hash" => "object"
      }.freeze

      # Instance-level attributes (override class delegators)
      attr_reader :tool_name, :description, :inputs, :output_type, :output_schema, :inject_models

      # Creates an inline tool from a name, description, inputs, and block.
      #
      # @param name [Symbol, String] Tool name
      # @param description [String] What the tool does
      # @param inject_models [Array<Symbol>] Model purposes to inject as keyword args
      # @param inputs [Hash{Symbol => Class}] Input name => type mappings
      # @param block [Proc] The tool implementation
      # @return [InlineTool]
      def self.create(name, description, inject_models: nil, **inputs, &block)
        validate_block!(name, block)
        build_from_inputs(name, description, inject_models, inputs, block)
      end

      def self.validate_block!(name, block)
        raise ToolConfigurationError.new("Block required for inline tool", tool_name: name.to_s) unless block
      end

      def self.build_from_inputs(name, description, inject_models, inputs, block)
        output_type = inputs.delete(:output_type) || "any"
        new(
          tool_name: name.to_s.freeze, description: description.to_s.freeze,
          inputs: inputs.transform_values { normalize_input_type(it) }.freeze,
          output_type: output_type.to_s.freeze,
          inject_models: Array(inject_models).map(&:to_sym).freeze, block:
        )
      end

      private_class_method :validate_block!, :build_from_inputs

      # Normalize input type - handles both Ruby classes and hash specifications.
      # Ensures description is always present for Tool validation.
      # Disables danger detection since inline tools are developer-defined (trusted code).
      # @api private
      def self.normalize_input_type(type)
        base = { description: "", detect_dangerous: false }
        if type.is_a?(Hash) && (type[:type] || type["type"])
          base.merge(type)
        else
          base.merge(type: ruby_type_to_schema(type))
        end
      end

      # Convert Ruby types to JSON Schema types.
      # @api private
      def self.ruby_type_to_schema(type)
        return type.to_s unless type.is_a?(Class)

        TYPE_MAP.fetch(type.name, "any")
      end

      # @param tool_name [String] Tool name
      # @param description [String] Tool description
      # @param inputs [Hash] Input schema
      # @param output_type [String] Output type
      # @param inject_models [Array<Symbol>] Model purposes to inject
      # @param block [Proc] Implementation block
      def initialize(tool_name:, description:, inputs:, output_type:, inject_models:, block:)
        @tool_name = tool_name
        @description = description
        @inputs = inputs
        @output_type = output_type
        @output_schema = nil
        @inject_models = inject_models
        @block = block
        super() # Validates and sets @initialized
      end

      # Alias for tool_name
      def name = tool_name

      # Execute the tool with given arguments.
      #
      # If inject_models was specified, resolved models are merged into kwargs.
      #
      # @param injected_models [Hash{Symbol => Model}] Models resolved from agent's pool
      # @param kwargs [Hash] Keyword arguments matching inputs
      # @return [Object] Result from the block
      def execute(injected_models: {}, **)
        merged_kwargs = inject_models.each_with_object({}.merge(**)) do |purpose, h|
          h[purpose] = injected_models[purpose] if injected_models.key?(purpose)
        end
        @block.call(**merged_kwargs)
      end

      # Check if this tool requires model injection.
      def requires_models? = !inject_models.empty?

      # Check if tool has been set up (always true for inline tools).
      def setup? = true

      # No-op setup for inline tools.
      def setup = self

      # Generate JSON Schema for this tool.
      # @return [Hash] JSON Schema representation
      def to_json_schema
        { type: "function", function: { name: tool_name, description:, parameters: parameters_schema } }
      end

      # Build the parameters portion of the JSON Schema.
      # @return [Hash] Parameters schema with properties and required fields
      def parameters_schema
        { type: "object", properties: inputs.transform_keys(&:to_s), required: inputs.keys.map(&:to_s) }
      end

      # String representation.
      def to_s = "InlineTool(#{tool_name})"
      def inspect = "#<InlineTool #{tool_name}: #{description[0, 40]}...>"
    end
  end

  # Re-export at Smolagents level
  InlineTool = Tools::InlineTool
end
