module Smolagents
  module Concerns
    # Tool schema conversion utilities
    #
    # Converts Smolagents tool definitions to various API schema formats
    # (JSON Schema, OpenAI, etc.)
    #
    # @example Get JSON Schema properties
    #   schema = tool_properties(my_tool)
    #   # => { query: { type: "string", description: "..." } }
    #
    # @example Get required fields
    #   required = tool_required_fields(my_tool)
    #   # => ["query"]
    module ToolSchema
      # Mapping from Smolagents types to JSON Schema types
      JSON_TYPE_MAP = {
        "string" => "string", "image" => "string", "audio" => "string",
        "integer" => "integer", "number" => "number", "boolean" => "boolean",
        "array" => "array", "object" => "object"
      }.freeze

      # Convert tool inputs to JSON Schema properties
      #
      # Extracts type and description from tool input specs.
      # Supports optional type mapping via callable.
      #
      # @param tool [Tool] Tool to extract properties from
      # @param type_mapper [Proc, nil] Optional callable to transform types
      # @return [Hash<String, Hash>] JSON Schema properties
      # @example
      #   props = tool_properties(search_tool)
      #   # => { query: { type: "string", description: "Search query" } }
      def tool_properties(tool, type_mapper: nil)
        tool.inputs.transform_values do |spec|
          type = type_mapper ? type_mapper.call(spec["type"]) : spec["type"]
          { type: type, description: spec["description"] }.tap do |prop|
            prop[:enum] = spec["enum"] if spec["enum"]
          end
        end
      end

      # Get required input fields for a tool
      #
      # Filters out optional (nullable) input fields.
      #
      # @param tool [Tool] Tool to inspect
      # @return [Array<String>] Required field names
      # @example
      #   required = tool_required_fields(search_tool)
      #   # => ["query"]
      def tool_required_fields(tool)
        tool.inputs.reject { |_, spec| spec["nullable"] }.keys
      end

      # Convert Smolagents type to JSON Schema type
      #
      # Uses JSON_TYPE_MAP for conversion, defaults to "string" for unknown types.
      #
      # @param type [String] Smolagents type name
      # @return [String] JSON Schema type
      # @example
      #   json_schema_type("integer")    # => "integer"
      #   json_schema_type("image")      # => "string"
      #   json_schema_type("unknown")    # => "string" (default)
      def json_schema_type(type)
        JSON_TYPE_MAP[type] || "string"
      end
    end
  end
end
