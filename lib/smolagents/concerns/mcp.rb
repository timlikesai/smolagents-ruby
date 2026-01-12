module Smolagents
  module Concerns
    module Mcp
      extend GemLoader

      class << self
        def create_client(transport:)
          require_mcp_gem
          ::MCP::Client.new(transport: transport)
        end

        def http_transport(url:, headers: {})
          require_mcp_gem
          ::MCP::Client::HTTP.new(url: url, headers: headers)
        end

        def fetch_tools(client)
          client.tools.map { |mcp_tool| MCPTool.new(mcp_tool, client: client) }
        end

        def convert_input_schema(input_schema)
          return {} unless input_schema.is_a?(Hash)

          properties = input_schema["properties"] || input_schema[:properties] || {}
          required = input_schema["required"] || input_schema[:required] || []

          properties.each_with_object({}) do |(name, spec), result|
            spec = spec.is_a?(Hash) ? spec.transform_keys(&:to_s) : {}
            result[name.to_sym] = {
              type: normalize_type(spec["type"]),
              description: spec["description"] || "No description provided",
              nullable: !required.include?(name.to_s)
            }
          end
        end

        def normalize_type(type)
          type_map = {
            "string" => "string",
            "boolean" => "boolean",
            "integer" => "integer",
            "number" => "number",
            "array" => "array",
            "object" => "object",
            "null" => "null"
          }

          if type.is_a?(Array)
            non_null = type.reject { |t| t == "null" }
            non_null.size == 1 ? type_map.fetch(non_null.first, "any") : "any"
          else
            type_map.fetch(type.to_s, "any")
          end
        end

        private

        def require_mcp_gem
          require "mcp"
        rescue LoadError
          raise LoadError, "MCP gem required for Model Context Protocol support. " \
                           "Add `gem 'mcp', '~> 0.5'` to your Gemfile."
        end
      end
    end
  end
end
