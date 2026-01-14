require "smolagents"
require "mcp"

RSpec.describe Smolagents::MCPTool do
  subject(:tool) { described_class.new(mcp_tool, client:) }

  let(:mcp_tool) do
    MCP::Client::Tool.new(
      name: "web_search",
      description: "Search the web for information",
      input_schema: {
        "properties" => {
          "query" => { "type" => "string", "description" => "Search query" },
          "limit" => { "type" => "integer", "description" => "Max results" }
        },
        "required" => ["query"]
      }
    )
  end

  let(:client) do
    instance_double(MCP::Client).tap do |c|
      allow(c).to receive(:call_tool).and_return(
        "content" => [{ "type" => "text", "text" => "Search results here" }]
      )
    end
  end

  describe "#initialize" do
    it "sets tool_name from MCP tool" do
      expect(tool.tool_name).to eq("web_search")
      expect(tool.name).to eq("web_search")
    end

    it "sets description from MCP tool" do
      expect(tool.description).to eq("Search the web for information")
    end

    it "converts input_schema to inputs format" do
      expect(tool.inputs).to include(:query, :limit)
      expect(tool.inputs[:query][:type]).to eq("string")
      expect(tool.inputs[:query][:description]).to eq("Search query")
    end

    it "marks required inputs as non-nullable" do
      expect(tool.inputs[:query][:nullable]).to be false
    end

    it "marks optional inputs as nullable" do
      expect(tool.inputs[:limit][:nullable]).to be true
    end

    it "sets output_type to any by default" do
      expect(tool.output_type).to eq("any")
    end

    it "stores the MCP tool reference" do
      expect(tool.mcp_tool).to eq(mcp_tool)
    end

    it "stores the client reference" do
      expect(tool.client).to eq(client)
    end
  end

  describe "#initialize with output_schema" do
    let(:mcp_tool_with_output) do
      MCP::Client::Tool.new(
        name: "calculator",
        description: "Calculate expressions",
        input_schema: { "properties" => { "expr" => { "type" => "string", "description" => "Expression" } } },
        output_schema: { "type" => "number" }
      )
    end

    it "determines output_type from output_schema" do
      tool = described_class.new(mcp_tool_with_output, client:)
      expect(tool.output_type).to eq("number")
    end
  end

  describe "#initialize with missing description" do
    let(:mcp_tool_no_desc) do
      MCP::Client::Tool.new(
        name: "simple_tool",
        description: nil,
        input_schema: {}
      )
    end

    it "provides a default description" do
      tool = described_class.new(mcp_tool_no_desc, client:)
      expect(tool.description).to eq("MCP tool: simple_tool")
    end
  end

  describe "#execute" do
    it "calls the MCP client with tool and arguments" do
      expect(client).to receive(:call_tool).with(
        tool: mcp_tool,
        arguments: { "query" => "test query", "limit" => "10" }
      )

      tool.execute(query: "test query", limit: "10")
    end

    it "extracts text content from response" do
      result = tool.execute(query: "test")

      expect(result).to eq("Search results here")
    end

    it "handles multiple content items" do
      allow(client).to receive(:call_tool).and_return(
        "content" => [
          { "type" => "text", "text" => "Line 1" },
          { "type" => "text", "text" => "Line 2" }
        ]
      )

      result = tool.execute(query: "test")

      expect(result).to eq("Line 1\nLine 2")
    end

    it "handles response with symbol keys" do
      allow(client).to receive(:call_tool).and_return(content: [{ type: "text", text: "Symbol result" }])

      result = tool.execute(query: "test")

      expect(result).to eq("Symbol result")
    end

    it "returns raw response when no content array" do
      allow(client).to receive(:call_tool).and_return({ "result" => "raw" })

      result = tool.execute(query: "test")

      expect(result).to eq({ "result" => "raw" })
    end
  end

  describe "#call" do
    it "wraps result in ToolResult" do
      result = tool.call(query: "test")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.data).to eq("Search results here")
      expect(result.tool_name).to eq("web_search")
    end

    it "can skip wrapping with wrap_result: false" do
      result = tool.call(query: "test", wrap_result: false)

      expect(result).to eq("Search results here")
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = tool.to_h

      expect(hash[:name]).to eq("web_search")
      expect(hash[:description]).to eq("Search the web for information")
      expect(hash[:inputs]).to include(:query, :limit)
      expect(hash[:output_type]).to eq("any")
    end
  end

  describe "#to_code_prompt" do
    it "generates compact code prompt" do
      prompt = tool.to_code_prompt

      expect(prompt).to include("web_search(")
      expect(prompt).to include("Search the web for information")
    end
  end

  describe "#to_tool_calling_prompt" do
    it "generates tool calling prompt" do
      prompt = tool.to_tool_calling_prompt

      expect(prompt).to include("web_search:")
      expect(prompt).to include("Search the web for information")
    end
  end
end
