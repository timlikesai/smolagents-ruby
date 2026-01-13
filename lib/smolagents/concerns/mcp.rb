module Smolagents
  module Concerns
    # Model Context Protocol (MCP) client support
    #
    # Provides utilities for connecting to MCP servers and exposing
    # MCP tools as Smolagents tools. The MCP gem is optional - a helpful
    # error is raised if not installed.
    #
    # @example Creating an MCP client
    #   transport = Smolagents::Concerns::Mcp.http_transport(
    #     url: "http://localhost:3000/mcp"
    #   )
    #   client = Smolagents::Concerns::Mcp.create_client(transport: transport)
    #   tools = Smolagents::Concerns::Mcp.fetch_tools(client)
    #
    # @example Using MCP tools in an agent
    #   mcp_tools = Smolagents::Concerns::Mcp.fetch_tools(mcp_client)
    #   agent = Smolagents::CodeAgent.new(model: model, tools: mcp_tools)
    #
    # @see https://modelcontextprotocol.io/ MCP Specification
    module Mcp
      extend GemLoader

      # Class methods for MCP operations
      class << self
        # Create an MCP client with the given transport
        #
        # @param transport [::MCP::Client::Transport] Transport instance (HTTP, SSE, etc.)
        # @return [::MCP::Client] Configured MCP client
        # @raise [LoadError] If mcp gem not installed
        # @example
        #   transport = MCP.http_transport(url: "http://localhost:3000")
        #   client = MCP.create_client(transport: transport)
        def create_client(transport:)
          require_mcp_gem
          ::MCP::Client.new(transport: transport)
        end

        # Create an HTTP transport for MCP
        #
        # @param url [String] HTTP URL to MCP server
        # @param headers [Hash] Optional HTTP headers (e.g., authorization)
        # @return [::MCP::Client::HTTP] HTTP transport instance
        # @raise [LoadError] If mcp gem not installed
        # @example
        #   transport = MCP.http_transport(
        #     url: "https://api.example.com/mcp",
        #     headers: { "Authorization" => "Bearer token" }
        #   )
        def http_transport(url:, headers: {})
          require_mcp_gem
          ::MCP::Client::HTTP.new(url: url, headers: headers)
        end

        # Fetch tools from MCP server
        #
        # Converts MCP tool definitions to Smolagents MCPTool instances.
        #
        # @param client [::MCP::Client] MCP client instance
        # @return [Array<MCPTool>] Smolagents-compatible tools
        # @example
        #   tools = MCP.fetch_tools(client)
        #   agent = CodeAgent.new(model: model, tools: tools)
        def fetch_tools(client)
          client.tools.map { |mcp_tool| MCPTool.new(mcp_tool, client: client) }
        end

        # Convert MCP input schema to Smolagents format
        #
        # Transforms MCP input schema definitions into the format
        # expected by Smolagents tool inputs.
        #
        # @param input_schema [Hash] MCP input schema
        # @return [Hash<String, Hash>] Smolagents-format tool inputs
        # @api private
        def convert_input_schema(input_schema)
          InputSchema.from_mcp_input_schema(input_schema).each_with_object({}) do |schema, result|
            result[schema.name] = schema.to_tool_input
          end
        end

        private

        # Load the MCP gem with helpful error message
        #
        # @return [void]
        # @raise [LoadError] If mcp gem not available with installation instructions
        # @api private
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
