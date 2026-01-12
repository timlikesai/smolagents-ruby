# frozen_string_literal: true

module Smolagents
  module Concerns
    # Provides Model Context Protocol (MCP) integration for connecting to MCP servers
    # and converting MCP tools to smolagents Tool objects.
    #
    # MCP is an open protocol that standardizes how applications provide context to LLMs.
    # This concern enables agents to use tools exposed by any MCP-compatible server.
    #
    # @example Using MCP tools with an agent
    #   tools = Smolagents::MCPToolCollection.from_server(
    #     transport: MCP::Client::HTTP.new(url: "http://localhost:3000/mcp")
    #   )
    #   agent = Smolagents::Agent.tool_calling(tools: tools.to_a, model: model)
    #
    module Mcp
      extend GemLoader

      class << self
        # Creates an MCP client with the given transport
        #
        # @param transport [#send_request] Transport layer (HTTP, stdio, or custom)
        # @return [MCP::Client] Configured MCP client
        def create_client(transport:)
          require_mcp_gem
          ::MCP::Client.new(transport: transport)
        end

        # Creates an HTTP transport for connecting to an MCP server
        #
        # @param url [String] MCP server URL
        # @param headers [Hash] Optional HTTP headers (e.g., for authentication)
        # @return [MCP::Client::HTTP] HTTP transport
        def http_transport(url:, headers: {})
          require_mcp_gem
          ::MCP::Client::HTTP.new(url: url, headers: headers)
        end

        # Fetches tools from an MCP server and converts them to smolagents Tools
        #
        # @param client [MCP::Client] MCP client instance
        # @return [Array<MCPTool>] Array of smolagents-compatible tools
        def fetch_tools(client)
          client.tools.map { |mcp_tool| MCPTool.new(mcp_tool, client: client) }
        end

        # Converts MCP input schema to smolagents inputs format
        #
        # @param input_schema [Hash] MCP tool input schema (JSON Schema format)
        # @return [Hash] smolagents-compatible inputs hash
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

        # Normalizes JSON Schema types to smolagents types
        #
        # @param type [String, Array] JSON Schema type(s)
        # @return [String] smolagents-compatible type
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
            # Handle union types like ["string", "null"]
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
