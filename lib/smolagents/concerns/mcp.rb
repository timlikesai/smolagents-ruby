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
          InputSchema.from_mcp_input_schema(input_schema).each_with_object({}) do |schema, result|
            result[schema.name] = schema.to_tool_input
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
