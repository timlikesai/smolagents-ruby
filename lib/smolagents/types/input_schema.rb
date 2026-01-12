module Smolagents
  InputSchema = Data.define(:name, :type, :description, :required, :nullable) do
    TYPE_MAP = {
      "string" => "string",
      "boolean" => "boolean",
      "integer" => "integer",
      "number" => "number",
      "array" => "array",
      "object" => "object",
      "null" => "null"
    }.freeze

    class << self
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

      def from_mcp_input_schema(input_schema)
        return [] unless input_schema.is_a?(Hash)

        properties = input_schema["properties"] || input_schema[:properties] || {}
        required = input_schema["required"] || input_schema[:required] || []

        properties.map { |name, spec| from_mcp_property(name, spec, required) }
      end

      def normalize_type(type)
        if type.is_a?(Array)
          non_null = type.reject { |t| t == "null" }
          non_null.size == 1 ? TYPE_MAP.fetch(non_null.first, "any") : "any"
        else
          TYPE_MAP.fetch(type.to_s, "any")
        end
      end
    end

    def to_tool_input
      {
        type: type,
        description: description,
        nullable: nullable
      }
    end

    def to_h
      { name: name, type: type, description: description, required: required, nullable: nullable }
    end
  end
end
