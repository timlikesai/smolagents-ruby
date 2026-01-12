# frozen_string_literal: true

module Smolagents
  module Concerns
    module ToolSchema
      JSON_TYPE_MAP = {
        "string" => "string", "image" => "string", "audio" => "string",
        "integer" => "integer", "number" => "number", "boolean" => "boolean",
        "array" => "array", "object" => "object"
      }.freeze

      def tool_properties(tool, type_mapper: nil)
        tool.inputs.transform_values do |spec|
          type = type_mapper ? type_mapper.call(spec["type"]) : spec["type"]
          { type: type, description: spec["description"] }.tap do |prop|
            prop[:enum] = spec["enum"] if spec["enum"]
          end
        end
      end

      def tool_required_fields(tool)
        tool.inputs.reject { |_, spec| spec["nullable"] }.keys
      end

      def json_schema_type(type)
        JSON_TYPE_MAP[type] || "string"
      end
    end
  end
end
