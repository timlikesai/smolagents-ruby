module Smolagents
  module Models
    module ModelSupport
      # Shared tool schema extraction for model request builders.
      #
      # Extracts common schema components (name, description, properties, required)
      # that each provider wraps in their specific format.
      #
      # @example Include in a request builder
      #   include ModelSupport::ToolSchema
      #
      #   def format_tools(tools)
      #     tools.map { |t| wrap_tool_schema(extract_tool_schema(t)) }
      #   end
      module ToolSchema
        # Extracts tool schema components for API formatting.
        #
        # Builds the common structure that all providers need, using
        # shared helpers from Concerns::ToolSchema (included in model classes).
        #
        # @param tool [Tool] Tool to extract schema from
        # @param type_mapper [Proc, nil] Optional type conversion callable
        # @return [Hash] Schema with :name, :description, :properties, :required
        # @example
        #   extract_tool_schema(search_tool)
        #   # => { name: "search", description: "...",
        #   #      properties: {...}, required: ["query"] }
        def extract_tool_schema(tool, type_mapper: nil)
          {
            name: tool.name,
            description: tool.description,
            properties: tool_properties(tool, type_mapper:),
            required: tool_required_fields(tool)
          }
        end

        # Wraps extracted schema in standard JSON Schema object format.
        #
        # Creates the `type: "object"` wrapper with properties and required.
        # Providers use this differently:
        # - OpenAI: wraps in `{ type: "function", function: { parameters: ... } }`
        # - Anthropic: wraps in `{ input_schema: ... }`
        #
        # @param schema [Hash] Extracted schema from {#extract_tool_schema}
        # @return [Hash] JSON Schema object structure
        def build_parameters_schema(schema)
          {
            type: "object",
            properties: schema[:properties],
            required: schema[:required]
          }
        end
      end
    end
  end
end
