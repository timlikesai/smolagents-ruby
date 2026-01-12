require "smolagents"
require "mcp"

RSpec.describe Smolagents::MCPToolCollection do
  let(:mcp_tools) do
    [
      MCP::Client::Tool.new(
        name: "search",
        description: "Search the web",
        input_schema: { "properties" => { "query" => { "type" => "string", "description" => "Query" } } }
      ),
      MCP::Client::Tool.new(
        name: "calculator",
        description: "Calculate expressions",
        input_schema: { "properties" => { "expr" => { "type" => "string", "description" => "Expression" } } }
      )
    ]
  end

  let(:mock_client) do
    instance_double(MCP::Client).tap do |c|
      allow(c).to receive(:tools).and_return(mcp_tools)
      allow(c).to receive(:call_tool).and_return({ content: [{ type: "text", text: "result" }] })
    end
  end

  let(:mock_transport) do
    instance_double(MCP::Client::HTTP).tap do |t|
      allow(t).to receive(:send_request).and_return({})
    end
  end

  before do
    allow(MCP::Client).to receive(:new).and_return(mock_client)
    allow(MCP::Client::HTTP).to receive(:new).and_return(mock_transport)
  end

  describe ".from_http" do
    it "creates collection from HTTP server" do
      collection = described_class.from_http(url: "http://localhost:3000/mcp")

      expect(collection).to be_a(described_class)
      expect(collection.size).to eq(2)
      expect(collection.server_url).to eq("http://localhost:3000/mcp")
    end

    it "passes headers to transport" do
      expect(MCP::Client::HTTP).to receive(:new).with(
        url: "http://localhost:3000/mcp",
        headers: { "Authorization" => "Bearer token" }
      ).and_return(mock_transport)

      described_class.from_http(
        url: "http://localhost:3000/mcp",
        headers: { "Authorization" => "Bearer token" }
      )
    end

    it "contains MCPTool instances" do
      collection = described_class.from_http(url: "http://localhost:3000/mcp")

      collection.each do |tool|
        expect(tool).to be_a(Smolagents::MCPTool)
      end
    end
  end

  describe ".from_server" do
    it "creates collection from transport" do
      collection = described_class.from_server(transport: mock_transport)

      expect(collection).to be_a(described_class)
      expect(collection.size).to eq(2)
    end

    it "stores optional server_url" do
      collection = described_class.from_server(
        transport: mock_transport,
        server_url: "http://example.com/mcp"
      )

      expect(collection.server_url).to eq("http://example.com/mcp")
    end

    it "stores the client reference" do
      collection = described_class.from_server(transport: mock_transport)

      expect(collection.client).to eq(mock_client)
    end
  end

  describe "#initialize" do
    it "accepts tools array" do
      tools = [
        instance_double(Smolagents::MCPTool, name: "tool1"),
        instance_double(Smolagents::MCPTool, name: "tool2")
      ]

      collection = described_class.new(tools)

      expect(collection.size).to eq(2)
    end

    it "accepts client and server_url" do
      collection = described_class.new([], client: mock_client, server_url: "http://example.com")

      expect(collection.client).to eq(mock_client)
      expect(collection.server_url).to eq("http://example.com")
    end
  end

  describe "#refresh!" do
    let(:collection) { described_class.from_http(url: "http://localhost:3000/mcp") }

    it "fetches fresh tools from server" do
      expect(mock_client).to receive(:tools).and_return(mcp_tools)

      collection.refresh!

      expect(collection.size).to eq(2)
    end

    it "returns self for chaining" do
      expect(collection.refresh!).to eq(collection)
    end

    it "raises error when no client available" do
      orphan_collection = described_class.new([])

      expect { orphan_collection.refresh! }.to raise_error("No client available for refresh")
    end
  end

  describe "#connection_info" do
    let(:collection) { described_class.from_http(url: "http://localhost:3000/mcp") }

    it "returns connection information" do
      info = collection.connection_info

      expect(info[:server_url]).to eq("http://localhost:3000/mcp")
      expect(info[:tool_count]).to eq(2)
      expect(info[:tool_names]).to contain_exactly("search", "calculator")
    end
  end

  describe "inherited ToolCollection methods" do
    let(:collection) { described_class.from_http(url: "http://localhost:3000/mcp") }

    it "supports [] lookup by name" do
      tool = collection["search"]

      expect(tool).to be_a(Smolagents::MCPTool)
      expect(tool.name).to eq("search")
    end

    it "supports names" do
      expect(collection.names).to contain_exactly("search", "calculator")
    end

    it "supports each iteration" do
      names = []
      collection.each { |t| names << t.name }

      expect(names).to contain_exactly("search", "calculator")
    end

    it "supports to_a for agent initialization" do
      tools_array = collection.to_a

      expect(tools_array).to be_an(Array)
      expect(tools_array.size).to eq(2)
    end

    it "supports include?" do
      expect(collection.include?("search")).to be true
      expect(collection.include?("nonexistent")).to be false
    end

    it "supports empty?" do
      expect(collection.empty?).to be false
      expect(described_class.new([]).empty?).to be true
    end
  end

  describe "integration with agents" do
    it "provides tools compatible with agent initialization" do
      collection = described_class.from_http(url: "http://localhost:3000/mcp")
      tools = collection.tools

      tools.each do |tool|
        expect(tool).to respond_to(:name)
        expect(tool).to respond_to(:description)
        expect(tool).to respond_to(:inputs)
        expect(tool).to respond_to(:output_type)
        expect(tool).to respond_to(:call)
        expect(tool).to respond_to(:execute)
      end
    end
  end
end
