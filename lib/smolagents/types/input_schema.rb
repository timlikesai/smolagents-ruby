module Smolagents
  # Immutable schema definition for a tool input parameter.
  #
  # InputSchema represents the specification of a single input parameter,
  # including its name, type, description, and whether it's required.
  # Commonly used to parse MCP tool schemas into Smolagents format.
  #
  # @example Creating from MCP property
  #   schema = InputSchema.from_mcp_property(
  #     "query",
  #     { "type" => "string", "description" => "Search query" },
  #     ["query"]  # required fields
  #   )
  #   schema.name        # => :query
  #   schema.required    # => true
  #
  # @example Parsing full MCP schema
  #   schemas = InputSchema.from_mcp_input_schema({
  #     "properties" => {
  #       "path" => { "type" => "string", "description" => "File path" }
  #     },
  #     "required" => ["path"]
  #   })
  #
  # @example Converting to tool input format
  #   schema.to_tool_input
  #   # => { type: "string", description: "File path", nullable: false }
  #
  # @see MCPTool Uses InputSchema for parsing MCP tool definitions
  InputSchema = Data.define(:name, :type, :description, :required, :nullable) do
    # @return [Hash{String => String}] JSON Schema type to internal type mapping
    TYPE_MAP = { # rubocop:disable Lint/ConstantDefinitionInBlock
      "string" => "string",
      "boolean" => "boolean",
      "integer" => "integer",
      "number" => "number",
      "array" => "array",
      "object" => "object",
      "null" => "null"
    }.freeze

    class << self
      # Creates an InputSchema from an MCP property definition.
      #
      # @param name [String, Symbol] Parameter name
      # @param spec [Hash] MCP property specification
      # @param required_names [Array<String>] List of required parameter names
      # @return [InputSchema] Parsed schema
      def from_mcp_property(name, spec, required_names)
        spec = spec.is_a?(Hash) ? spec.transform_keys(&:to_s) : {}
        required_list = Array(required_names).map(&:to_s)

        new(
          name: name.to_sym,
          type: normalize_type(spec["type"]),
          description: spec["description"] || "No description provided",
          required: required_list.include?(name.to_s),
          nullable: !required_list.include?(name.to_s)
        )
      end

      # Parses a full MCP input schema into an array of InputSchema objects.
      #
      # @param input_schema [Hash] MCP input schema with properties and required
      # @return [Array<InputSchema>] Parsed schemas for each property
      def from_mcp_input_schema(input_schema)
        return [] unless input_schema.is_a?(Hash)

        properties = input_schema["properties"] || input_schema[:properties] || {}
        required = input_schema["required"] || input_schema[:required] || []

        properties.map { |name, spec| from_mcp_property(name, spec, required) }
      end

      # Normalizes a JSON Schema type to internal type string.
      #
      # Handles union types (e.g., ["string", "null"]) by extracting
      # the non-null type.
      #
      # @param type [String, Array<String>] JSON Schema type
      # @return [String] Normalized type string ("string", "integer", etc. or "any")
      def normalize_type(type)
        if type.is_a?(Array)
          non_null = type.reject { |type_str| type_str == "null" }
          non_null.size == 1 ? TYPE_MAP.fetch(non_null.first, "any") : "any"
        else
          TYPE_MAP.fetch(type.to_s, "any")
        end
      end
    end

    # Converts to Smolagents tool input format.
    # @return [Hash] Tool input specification
    def to_tool_input
      {
        type: type,
        description: description,
        nullable: nullable
      }
    end

    # Converts to a hash for serialization.
    # @return [Hash] Schema as a hash
    def to_h
      { name: name, type: type, description: description, required: required, nullable: nullable }
    end
  end
end
