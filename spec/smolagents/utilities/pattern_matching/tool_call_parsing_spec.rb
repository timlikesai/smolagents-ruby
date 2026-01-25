RSpec.describe Smolagents::Utilities::PatternMatching::ToolCallParsing do
  describe ".extract_tool_call_xml" do
    it "extracts tool call from XML format" do
      text = '<tool_call>{"name": "search", "arguments": {"query": "ruby"}}</tool_call>'
      result = described_class.extract_tool_call_xml(text)

      expect(result).to include("result = search")
      expect(result).to include("query:")
    end

    it "handles whitespace in XML tags" do
      text = '<tool_call>  {"name": "search", "arguments": {"q": "test"}}  </tool_call>'
      result = described_class.extract_tool_call_xml(text)

      expect(result).not_to be_nil
      expect(result).to include("search")
    end

    it "returns nil when no XML found" do
      text = "Just plain text"
      result = described_class.extract_tool_call_xml(text)

      expect(result).to be_nil
    end

    it "returns nil for invalid JSON in XML" do
      text = "<tool_call>{invalid json}</tool_call>"
      result = described_class.extract_tool_call_xml(text)

      expect(result).to be_nil
    end

    it "handles multiple arguments" do
      text = '<tool_call>{"name": "calc", "arguments": {"a": 1, "b": 2}}</tool_call>'
      result = described_class.extract_tool_call_xml(text)

      expect(result).to include("a:")
      expect(result).to include("b:")
    end

    it "handles case-insensitive XML tags" do
      text = '<TOOL_CALL>{"name": "test", "arguments": {}}</TOOL_CALL>'
      result = described_class.extract_tool_call_xml(text)

      expect(result).not_to be_nil
    end

    it "extracts first tool call when multiple present" do
      text = '<tool_call>{"name": "first", "arguments": {}}</tool_call>' \
             '<tool_call>{"name": "second", "arguments": {}}</tool_call>'
      result = described_class.extract_tool_call_xml(text)

      expect(result).to include("first")
    end
  end

  describe ".extract_tool_request" do
    it "extracts tool call from markdown format" do
      text = "```tool_request\n{\"name\": \"search\", \"arguments\": {\"query\": \"ruby\"}}\n```"
      result = described_class.extract_tool_request(text)

      expect(result).to include("result = search")
      expect(result).to include("query:")
    end

    it "handles whitespace in markdown" do
      # Trailing whitespace after JSON is allowed before the newline
      text = "```tool_request\n{\"name\": \"test\", \"arguments\": {}}  \n```"
      result = described_class.extract_tool_request(text)

      expect(result).not_to be_nil
    end

    it "returns nil when no markdown found" do
      text = "Just plain text"
      result = described_class.extract_tool_request(text)

      expect(result).to be_nil
    end

    it "returns nil for invalid JSON in markdown" do
      text = "```tool_request\n{bad json}\n```"
      result = described_class.extract_tool_request(text)

      expect(result).to be_nil
    end

    it "handles nested JSON in markdown" do
      text = %(```tool_request
{"name": "search", "arguments": {"filter": {"type": "advanced"}}}
```)
      result = described_class.extract_tool_request(text)

      expect(result).to include("search")
    end
  end

  describe ".extract_tool_json" do
    it "extracts from XML pattern" do
      text = '<tool_call>{"name": "calc", "arguments": {"x": 5}}</tool_call>'
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to include("calc")
      expect(result).to include("x:")
    end

    it "extracts from markdown pattern" do
      text = "```tool_request\n{\"name\": \"search\", \"arguments\": {\"q\": \"test\"}}\n```"
      result = described_class.extract_tool_json(text, described_class::TOOL_REQUEST_MD)

      expect(result).to include("search")
    end

    it "returns nil when pattern doesn't match" do
      text = "no matching pattern"
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to be_nil
    end

    it "returns nil for invalid JSON" do
      text = "<tool_call>{not valid json}</tool_call>"
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to be_nil
    end

    it "handles missing name field" do
      text = '<tool_call>{"arguments": {"q": "test"}}</tool_call>'
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to be_nil
    end

    it "handles missing arguments field" do
      text = '<tool_call>{"name": "search"}</tool_call>'
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to be_nil
    end

    it "handles empty arguments" do
      text = '<tool_call>{"name": "test", "arguments": {}}</tool_call>'
      result = described_class.extract_tool_json(text, described_class::TOOL_CALL_XML)

      expect(result).to eq("result = test()")
    end
  end

  describe ".tool_call_to_ruby" do
    it "converts tool call to Ruby code" do
      result = described_class.tool_call_to_ruby("search", { "query" => "ruby" })

      expect(result).to include("result = search")
      expect(result).to include("query:")
    end

    it "formats string arguments with inspect" do
      result = described_class.tool_call_to_ruby("test", { "name" => "value" })

      expect(result).to include('"value"')
    end

    it "formats numeric arguments" do
      result = described_class.tool_call_to_ruby("calc", { "num" => 42 })

      expect(result).to include("num: 42")
    end

    it "formats boolean arguments" do
      result = described_class.tool_call_to_ruby("toggle", { "enabled" => true })

      expect(result).to include("enabled: true")
    end

    it "formats multiple arguments" do
      result = described_class.tool_call_to_ruby("func", { "a" => 1, "b" => 2 })

      expect(result).to include("a: 1")
      expect(result).to include("b: 2")
    end

    it "returns nil when name is nil" do
      result = described_class.tool_call_to_ruby(nil, { "arg" => "value" })

      expect(result).to be_nil
    end

    it "returns nil when args is nil" do
      result = described_class.tool_call_to_ruby("search", nil)

      expect(result).to be_nil
    end

    it "starts with 'result =' for consistency" do
      result = described_class.tool_call_to_ruby("search", { "q" => "test" })

      expect(result).to start_with("result = ")
    end

    it "handles hash arguments" do
      result = described_class.tool_call_to_ruby("config", { "opts" => { "key" => "val" } })

      expect(result).to include("opts:")
    end

    it "handles array arguments" do
      result = described_class.tool_call_to_ruby("process", { "items" => [1, 2, 3] })

      expect(result).to include("items:")
    end

    it "handles nested structures" do
      args = { "filter" => { "type" => "advanced", "count" => 10 } }
      result = described_class.tool_call_to_ruby("search", args)

      expect(result).to include("search")
      expect(result).to include("filter:")
    end
  end

  describe "TOOL_CALL_XML constant" do
    it "is a Regexp" do
      expect(described_class::TOOL_CALL_XML).to be_a(Regexp)
    end

    it "matches XML format" do
      text = '<tool_call>{"test": true}</tool_call>'
      expect(text).to match(described_class::TOOL_CALL_XML)
    end

    it "captures JSON content" do
      text = '<tool_call>{"captured": "json"}</tool_call>'
      match = text.match(described_class::TOOL_CALL_XML)

      expect(match[1]).to include("captured")
    end
  end

  describe "TOOL_REQUEST_MD constant" do
    it "is a Regexp" do
      expect(described_class::TOOL_REQUEST_MD).to be_a(Regexp)
    end

    it "matches markdown format" do
      text = "```tool_request\n{\"test\": true}\n```"
      expect(text).to match(described_class::TOOL_REQUEST_MD)
    end

    it "captures JSON content" do
      text = "```tool_request\n{\"captured\": \"json\"}\n```"
      match = text.match(described_class::TOOL_REQUEST_MD)

      expect(match[1]).to include("captured")
    end
  end
end
