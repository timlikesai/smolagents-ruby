module Smolagents
  # A specialized tool collection for Model Context Protocol (MCP) servers.
  #
  # MCPToolCollection extends ToolCollection to manage tools discovered from
  # MCP servers. It maintains a connection to the server for tool execution
  # and supports refreshing the tool list when server capabilities change.
  #
  # Use the factory methods to connect to MCP servers and automatically
  # discover available tools. Each tool is wrapped as an MCPTool that proxies
  # calls to the MCP server.
  #
  # @example Connecting to an HTTP MCP server
  #   # Connect and discover tools automatically
  #   collection = MCPToolCollection.from_http(
  #     url: "http://localhost:3000/mcp",
  #     headers: { "Authorization" => "Bearer token" }
  #   )
  #
  #   # Use tools with an agent
  #   agent = CodeAgent.new(model: model, tools: collection.tools)
  #   agent.run("List all files in the project directory")
  #
  # @example Using tools from the collection
  #   collection = MCPToolCollection.from_http(url: "http://mcp-server/api")
  #
  #   # Inspect available tools
  #   collection.names  # => ["read_file", "write_file", "list_directory"]
  #   collection.size   # => 3
  #
  #   # Access individual tools
  #   read_tool = collection["read_file"]
  #   result = read_tool.call(path: "/etc/hosts")
  #
  #   # Connection info for debugging
  #   collection.connection_info
  #   # => { server_url: "http://...", tool_count: 3, tool_names: [...] }
  #
  # @example Refreshing tools when server changes
  #   # Mutate in place (updates existing collection)
  #   collection.refresh!
  #
  #   # Or create a new collection with fresh tools
  #   new_collection = collection.refresh
  #
  # @see MCPTool Individual MCP tool wrapper
  # @see ToolCollection Base class for tool collections
  # @see Concerns::Mcp MCP protocol utilities
  class MCPToolCollection < ToolCollection
    # @return [Object, nil] The MCP client for server communication
    attr_reader :client

    # @return [String, nil] The URL of the connected MCP server
    attr_reader :server_url

    # Creates a collection by connecting to an HTTP MCP server.
    #
    # Establishes an HTTP transport connection, creates an MCP client,
    # fetches available tools, and wraps each as an MCPTool.
    #
    # @param url [String] The MCP server URL endpoint
    # @param headers [Hash] Additional HTTP headers (e.g., authentication)
    # @return [MCPToolCollection] Collection populated with server tools
    #
    # @raise [LoadError] If the MCP gem is not installed
    # @raise [StandardError] On connection or protocol errors
    #
    # @example
    #   collection = MCPToolCollection.from_http(
    #     url: "http://localhost:8080/mcp",
    #     headers: { "X-API-Key" => "secret" }
    #   )
    def self.from_http(url:, headers: {})
      transport = Concerns::Mcp.http_transport(url: url, headers: headers)
      from_server(transport: transport, server_url: url)
    end

    # Creates a collection from an MCP transport.
    #
    # Lower-level factory for custom transports (e.g., stdio, WebSocket).
    #
    # @param transport [Object] MCP transport instance
    # @param server_url [String, nil] Optional server URL for reference
    # @return [MCPToolCollection] Collection populated with server tools
    #
    # @raise [LoadError] If the MCP gem is not installed
    #
    # @example Custom transport
    #   transport = MCP::Client::Stdio.new(command: "./mcp-server")
    #   collection = MCPToolCollection.from_server(transport: transport)
    def self.from_server(transport:, server_url: nil)
      client = Concerns::Mcp.create_client(transport: transport)
      tools = Concerns::Mcp.fetch_tools(client)
      new(tools, client: client, server_url: server_url)
    end

    # Creates a new MCP tool collection.
    #
    # @param tools [Array<MCPTool>] Initial tools (default: empty)
    # @param client [Object, nil] MCP client for refreshing tools
    # @param server_url [String, nil] Server URL for reference
    def initialize(tools = [], client: nil, server_url: nil)
      super(tools)
      @client = client
      @server_url = server_url
    end

    # Refreshes the tool list from the server in place.
    #
    # Re-fetches tools from the MCP server and replaces the current
    # tool list. Use this when tools may have been added or removed
    # on the server.
    #
    # @return [self] The updated collection
    # @raise [RuntimeError] If no client is available for refresh
    #
    # @example
    #   collection.refresh!
    #   puts "Now have #{collection.size} tools"
    def refresh!
      raise "No client available for refresh" unless client

      @tools = Concerns::Mcp.fetch_tools(client)
      self
    end

    # Creates a new collection with refreshed tools from the server.
    #
    # Fetches the current tool list from the server and returns a new
    # collection, leaving the original unchanged.
    #
    # @return [MCPToolCollection] New collection with fresh tools
    # @raise [RuntimeError] If no client is available for refresh
    #
    # @example
    #   updated = collection.refresh
    #   # collection still has original tools
    #   # updated has new tools from server
    def refresh
      raise "No client available for refresh" unless client

      fresh_tools = Concerns::Mcp.fetch_tools(client)
      self.class.new(fresh_tools, client: client, server_url: server_url)
    end

    # Returns connection and tool information for debugging.
    #
    # @return [Hash] Connection details including server URL, tool count, and names
    #
    # @example
    #   info = collection.connection_info
    #   # => {
    #   #      server_url: "http://localhost:3000/mcp",
    #   #      tool_count: 5,
    #   #      tool_names: ["read_file", "write_file", ...]
    #   #    }
    def connection_info
      {
        server_url: server_url,
        tool_count: size,
        tool_names: names
      }
    end
  end
end
