# frozen_string_literal: true

module Smolagents
  # Collection of tools fetched from an MCP (Model Context Protocol) server.
  #
  # Provides factory methods to easily connect to MCP servers and retrieve
  # their tools as smolagents-compatible Tool objects.
  #
  # @example Connecting via HTTP
  #   collection = MCPToolCollection.from_http(
  #     url: "http://localhost:3000/mcp",
  #     headers: { "Authorization" => "Bearer token" }
  #   )
  #   agent = Agent.tool_calling(tools: collection.to_a, model: model)
  #
  # @example Using a custom transport
  #   transport = MCP::Client::HTTP.new(url: "http://localhost:3000/mcp")
  #   collection = MCPToolCollection.from_server(transport: transport)
  #
  class MCPToolCollection < ToolCollection
    attr_reader :client, :server_url

    # Creates collection by connecting to an MCP server via HTTP
    #
    # @param url [String] MCP server URL
    # @param headers [Hash] Optional HTTP headers for authentication
    # @return [MCPToolCollection] Collection with tools from the server
    def self.from_http(url:, headers: {})
      transport = Concerns::Mcp.http_transport(url: url, headers: headers)
      from_server(transport: transport, server_url: url)
    end

    # Creates collection from an MCP server using a custom transport
    #
    # @param transport [#send_request] Transport layer instance
    # @param server_url [String, nil] Optional server URL for reference
    # @return [MCPToolCollection] Collection with tools from the server
    def self.from_server(transport:, server_url: nil)
      client = Concerns::Mcp.create_client(transport: transport)
      tools = Concerns::Mcp.fetch_tools(client)
      new(tools, client: client, server_url: server_url)
    end

    # Creates a new MCPToolCollection
    #
    # @param tools [Array<MCPTool>] Array of MCP tools
    # @param client [MCP::Client] The MCP client instance
    # @param server_url [String, nil] Optional server URL for reference
    def initialize(tools = [], client: nil, server_url: nil)
      super(tools)
      @client = client
      @server_url = server_url
    end

    # Refreshes the tool list from the MCP server
    #
    # @return [self] Returns self for chaining
    def refresh!
      raise "No client available for refresh" unless client

      @tools = Concerns::Mcp.fetch_tools(client)
      self
    end

    # Returns server connection info for debugging
    #
    # @return [Hash] Connection information
    def connection_info
      {
        server_url: server_url,
        tool_count: size,
        tool_names: names
      }
    end
  end
end
