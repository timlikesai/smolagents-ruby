module Smolagents
  module Tools
    # Inline tool defined by a block - no class required.
    #
    # InlineTool wraps a block as a callable tool with the same interface as Tool.
    # Use this for simple, one-off tools defined directly in the agent builder.
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
    # @example Lambda conversion (same thing, different syntax)
    #   greet = ->(name:) { "Hello, #{name}!" }
    #   agent = Smolagents.agent
    #     .tool(:greet, "Generate a greeting", name: String, &greet)
    #     .model { model }
    #     .build
    #
    # @see AgentBuilder#tool Method that creates InlineTool instances
    # @see Tool Class-based tools for complex cases

    # Ruby type to JSON Schema type mapping.
    INLINE_TOOL_TYPE_MAP = {
      "String" => "string", "Integer" => "integer", "Float" => "number",
      "TrueClass" => "boolean", "FalseClass" => "boolean",
      "Array" => "array", "Hash" => "object"
    }.freeze

    InlineTool = Data.define(:tool_name, :description, :inputs, :output_type, :block) do
      # Creates an inline tool from a name, description, inputs, and block.
      #
      # @param name [Symbol, String] Tool name
      # @param description [String] What the tool does
      # @param inputs [Hash{Symbol => Class}] Input name => type mappings (passed as keyword args)
      # @param block [Proc] The tool implementation
      # @return [InlineTool]
      def self.create(name, description, **inputs, &block)
        raise ArgumentError, "Block required for inline tool" unless block

        # Extract output_type if provided, otherwise default to "any"
        output_type = inputs.delete(:output_type) || "any"

        # Convert Ruby types to JSON Schema types
        schema_inputs = inputs.transform_values { |type| { type: ruby_type_to_schema(type), description: "" } }

        new(
          tool_name: name.to_s.freeze,
          description: description.to_s.freeze,
          inputs: schema_inputs.freeze,
          output_type: output_type.to_s.freeze,
          block:
        )
      end

      # Convert Ruby types to JSON Schema types.
      # @api private
      def self.ruby_type_to_schema(type)
        return type.to_s unless type.is_a?(Class)

        INLINE_TOOL_TYPE_MAP.fetch(type.name, "any")
      end

      # Alias for tool_name
      def name = tool_name

      # Execute the tool with given arguments.
      #
      # @param kwargs [Hash] Keyword arguments matching inputs
      # @return [Object] Result from the block
      def execute(**)
        block.call(**)
      end

      # Call the tool and wrap result in ToolResult.
      #
      # @param kwargs [Hash] Keyword arguments matching inputs
      # @return [ToolResult] Chainable result wrapper
      def call(**)
        result = execute(**)
        ToolResult.new(result, tool_name:)
      end

      # Generate JSON Schema for this tool.
      # @return [Hash] JSON Schema representation
      def to_json_schema
        {
          type: "function",
          function: {
            name: tool_name,
            description:,
            parameters: parameters_schema
          }
        }
      end

      # Build the parameters portion of the JSON Schema.
      # @return [Hash] Parameters schema with properties and required fields
      def parameters_schema
        {
          type: "object",
          properties: inputs.transform_keys(&:to_s),
          required: inputs.keys.map(&:to_s)
        }
      end

      # Format this tool for the given context.
      #
      # @param format [Symbol] Format type (:code, :tool_calling, etc.)
      # @return [String] Formatted tool description
      def format_for(format)
        ToolFormatter.format(self, format:)
      end

      # Generates a prompt for CodeAgent showing how to call this tool.
      #
      # @return [String] Tool signature and description
      # @deprecated Use {#format_for}(:code) instead
      def to_code_prompt
        format_for(:code)
      end

      # Generates a natural language prompt for ToolAgent.
      #
      # @return [String] Natural language tool description
      # @deprecated Use {#format_for}(:tool_calling) instead
      def to_tool_calling_prompt
        format_for(:tool_calling)
      end

      # Converts the tool's metadata to a hash.
      #
      # @return [Hash{Symbol => Object}] Tool metadata
      def to_h = { name: tool_name, description:, inputs:, output_type: }

      # Check if tool has been set up (always true for inline tools).
      def setup? = true

      # No-op setup for compatibility with Tool interface.
      def setup = self

      # String representation.
      def to_s = "InlineTool(#{tool_name})"
      def inspect = "#<InlineTool #{tool_name}: #{description[0, 40]}...>"
    end
  end

  # Re-export at Smolagents level
  InlineTool = Tools::InlineTool
end
