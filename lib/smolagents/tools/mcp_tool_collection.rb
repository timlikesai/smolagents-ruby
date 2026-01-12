module Smolagents
  class MCPToolCollection < ToolCollection
    attr_reader :client, :server_url

    def self.from_http(url:, headers: {})
      transport = Concerns::Mcp.http_transport(url: url, headers: headers)
      from_server(transport: transport, server_url: url)
    end

    def self.from_server(transport:, server_url: nil)
      client = Concerns::Mcp.create_client(transport: transport)
      tools = Concerns::Mcp.fetch_tools(client)
      new(tools, client: client, server_url: server_url)
    end

    def initialize(tools = [], client: nil, server_url: nil)
      super(tools)
      @client = client
      @server_url = server_url
    end

    def refresh!
      raise "No client available for refresh" unless client

      @tools = Concerns::Mcp.fetch_tools(client)
      self
    end

    def refresh
      raise "No client available for refresh" unless client

      fresh_tools = Concerns::Mcp.fetch_tools(client)
      self.class.new(fresh_tools, client: client, server_url: server_url)
    end

    def connection_info
      {
        server_url: server_url,
        tool_count: size,
        tool_names: names
      }
    end
  end
end
