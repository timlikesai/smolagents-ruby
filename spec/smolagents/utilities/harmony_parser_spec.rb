require "smolagents/utilities/harmony_parser"

RSpec.describe Smolagents::Utilities::HarmonyParser do
  describe ".harmony_format?" do
    it "returns true for responses with channel markers" do
      text = "<|channel|>commentary to=search<|message|>{\"query\": \"hello\"}"
      expect(described_class.harmony_format?(text)).to be true
    end

    it "returns true for complex harmony responses" do
      text = <<~HARMONY
        <|start|>assistant<|channel|>commentary to=searxng_search code<|message|>{"query":"trending programming languages 2026"}
      HARMONY
      expect(described_class.harmony_format?(text)).to be true
    end

    it "returns false for standard code blocks" do
      text = "```ruby\nputs 'hello'\n```"
      expect(described_class.harmony_format?(text)).to be false
    end

    it "returns false for nil" do
      expect(described_class.harmony_format?(nil)).to be false
    end

    it "returns false for empty string" do
      expect(described_class.harmony_format?("")).to be false
    end

    it "returns false for plain text" do
      expect(described_class.harmony_format?("Just some text")).to be false
    end
  end

  describe ".extract_tool_calls" do
    it "extracts single tool call" do
      text = "<|channel|>commentary to=search<|message|>{\"query\": \"hello world\"}"
      calls = described_class.extract_tool_calls(text)

      expect(calls.size).to eq(1)
      expect(calls.first[:name]).to eq("search")
      expect(calls.first[:arguments]).to eq({ "query" => "hello world" })
    end

    it "extracts tool call from gpt-oss format" do
      text = "<|channel|>commentary to=searxng_search code<|message|>" \
             '{"query":"trending programming languages 2026"}'
      calls = described_class.extract_tool_calls(text)

      expect(calls.size).to eq(1)
      expect(calls.first[:name]).to eq("searxng_search")
      expect(calls.first[:arguments]).to eq({ "query" => "trending programming languages 2026" })
    end

    it "extracts multiple tool calls" do
      text = <<~HARMONY
        <|channel|>commentary to=search<|message|>{"query": "first"}
        <|channel|>commentary to=calculate<|message|>{"expression": "2+2"}
      HARMONY
      calls = described_class.extract_tool_calls(text)

      expect(calls.size).to eq(2)
      expect(calls[0][:name]).to eq("search")
      expect(calls[1][:name]).to eq("calculate")
    end

    it "handles tool calls with multiple arguments" do
      text = "<|channel|>commentary to=weather<|message|>{\"city\": \"Tokyo\", \"units\": \"celsius\"}"
      calls = described_class.extract_tool_calls(text)

      expect(calls.first[:arguments]).to eq({
                                              "city" => "Tokyo",
                                              "units" => "celsius"
                                            })
    end

    it "skips malformed JSON" do
      text = "<|channel|>commentary to=search<|message|>{invalid json}"
      calls = described_class.extract_tool_calls(text)

      expect(calls).to be_empty
    end

    it "returns empty array for non-harmony text" do
      text = "```ruby\nputs 'hello'\n```"
      calls = described_class.extract_tool_calls(text)

      expect(calls).to be_empty
    end
  end

  describe ".to_ruby_code" do
    it "converts single tool call to Ruby code" do
      text = "<|channel|>commentary to=search<|message|>{\"query\": \"hello\"}"
      code = described_class.to_ruby_code(text)

      expect(code).to eq('result = search(query: "hello")')
    end

    it "converts tool call with multiple arguments" do
      text = "<|channel|>commentary to=weather<|message|>{\"city\": \"Tokyo\", \"units\": \"celsius\"}"
      code = described_class.to_ruby_code(text)

      expect(code).to include("weather(")
      expect(code).to include('city: "Tokyo"')
      expect(code).to include('units: "celsius"')
    end

    it "converts multiple tool calls to multiple lines" do
      text = <<~HARMONY
        <|channel|>commentary to=search<|message|>{"query": "first"}
        <|channel|>commentary to=calculate<|message|>{"expression": "2+2"}
      HARMONY
      code = described_class.to_ruby_code(text)

      expect(code).to include('result = search(query: "first")')
      expect(code).to include('result = calculate(expression: "2+2")')
    end

    it "handles gpt-oss-20b actual output format" do
      # Real output from gpt-oss-20b
      text = "<|channel|>commentary to=searxng_search code<|message|>" \
             '{"query":"trending programming languages 2026"}'
      code = described_class.to_ruby_code(text)

      expect(code).to eq('result = searxng_search(query: "trending programming languages 2026")')
    end

    it "returns nil for non-harmony text" do
      text = "```ruby\nputs 'hello'\n```"
      code = described_class.to_ruby_code(text)

      expect(code).to be_nil
    end

    it "returns nil when no tool calls found" do
      text = "<|channel|>final<|message|>The answer is 42"
      code = described_class.to_ruby_code(text)

      expect(code).to be_nil
    end

    it "handles numeric arguments" do
      text = "<|channel|>commentary to=calculate<|message|>{\"a\": 5, \"b\": 10}"
      code = described_class.to_ruby_code(text)

      expect(code).to eq("result = calculate(a: 5, b: 10)")
    end

    it "handles boolean arguments" do
      text = "<|channel|>commentary to=config<|message|>{\"enabled\": true, \"debug\": false}"
      code = described_class.to_ruby_code(text)

      expect(code).to include("enabled: true")
      expect(code).to include("debug: false")
    end
  end

  describe ".extract_final_answer" do
    it "extracts final answer from final channel" do
      text = "<|channel|>final<|message|>The capital of France is Paris."
      answer = described_class.extract_final_answer(text)

      expect(answer).to eq("The capital of France is Paris.")
    end

    it "returns nil when no final channel" do
      text = "<|channel|>commentary to=search<|message|>{\"query\": \"hello\"}"
      answer = described_class.extract_final_answer(text)

      expect(answer).to be_nil
    end
  end

  describe ".strip_markers" do
    it "removes all harmony markers" do
      text = "<|start|>assistant<|channel|>final<|message|>The answer is 42"
      stripped = described_class.strip_markers(text)

      expect(stripped).not_to include("<|")
      expect(stripped).not_to include("|>")
      expect(stripped).to include("assistant")
      expect(stripped).to include("The answer is 42")
    end

    it "removes commentary channel markers" do
      text = "Some text commentary to=search more text"
      stripped = described_class.strip_markers(text)

      expect(stripped).not_to include("commentary to=search")
      expect(stripped).to include("Some text")
      expect(stripped).to include("more text")
    end
  end
end
