require "smolagents"
require "mcp"

RSpec.describe Smolagents::Concerns::Mcp do
  describe ".create_client" do
    it "creates an MCP client with the given transport" do
      transport = MCP::Client::HTTP.new(url: "http://example.com/mcp")
      client = described_class.create_client(transport:)

      expect(client).to be_a(MCP::Client)
      expect(client.transport).to eq(transport)
    end
  end

  describe ".http_transport" do
    it "creates an HTTP transport with URL" do
      transport = described_class.http_transport(url: "http://example.com/mcp")

      expect(transport).to be_a(MCP::Client::HTTP)
    end

    it "accepts custom headers without error" do
      expect do
        described_class.http_transport(
          url: "http://example.com/mcp",
          headers: { "Authorization" => "Bearer token" }
        )
      end.not_to raise_error
    end
  end

  describe ".convert_input_schema" do
    it "converts simple properties" do
      schema = {
        "properties" => {
          "query" => { "type" => "string", "description" => "Search query" },
          "limit" => { "type" => "integer", "description" => "Max results" }
        },
        "required" => ["query"]
      }

      result = described_class.convert_input_schema(schema)

      expect(result[:query][:type]).to eq("string")
      expect(result[:query][:description]).to eq("Search query")
      expect(result[:query][:nullable]).to be false

      expect(result[:limit][:type]).to eq("integer")
      expect(result[:limit][:nullable]).to be true
    end

    it "handles symbol keys" do
      schema = {
        properties: {
          name: { type: "string", description: "Name" }
        },
        required: ["name"]
      }

      result = described_class.convert_input_schema(schema)

      expect(result[:name][:type]).to eq("string")
      expect(result[:name][:nullable]).to be false
    end

    it "handles missing description" do
      schema = {
        "properties" => {
          "value" => { "type" => "number" }
        }
      }

      result = described_class.convert_input_schema(schema)

      expect(result[:value][:description]).to eq("No description provided")
    end

    it "returns empty hash for nil input" do
      expect(described_class.convert_input_schema(nil)).to eq({})
    end

    it "returns empty hash for non-hash input" do
      expect(described_class.convert_input_schema("invalid")).to eq({})
    end
  end

  describe ".fetch_tools" do
    let(:mcp_tool) do
      MCP::Client::Tool.new(
        name: "search",
        description: "Search the web",
        input_schema: { "properties" => { "query" => { "type" => "string", "description" => "Query" } } }
      )
    end

    let(:client) do
      instance_double(MCP::Client).tap do |c|
        allow(c).to receive_messages(tools: [mcp_tool], call_tool: { content: [{ type: "text", text: "result" }] })
      end
    end

    it "converts MCP tools to MCPTool instances" do
      tools = described_class.fetch_tools(client)

      expect(tools.size).to eq(1)
      expect(tools.first).to be_a(Smolagents::MCPTool)
      expect(tools.first.name).to eq("search")
    end
  end
end
