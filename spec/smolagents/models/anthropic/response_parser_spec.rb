require "spec_helper"

RSpec.describe Smolagents::Models::Anthropic::ResponseParser do
  let(:parser_class) do
    Class.new { include Smolagents::Models::Anthropic::ResponseParser }
  end
  let(:parser) { parser_class.new }

  describe "#parse_response" do
    context "with simple text response" do
      let(:response) do
        {
          "content" => [{ "type" => "text", "text" => "Hello from Claude!" }],
          "usage" => { "input_tokens" => 10, "output_tokens" => 8 }
        }
      end

      it "extracts content" do
        result = parser.parse_response(response)
        expect(result.content).to eq("Hello from Claude!")
      end

      it "parses token usage" do
        result = parser.parse_response(response)
        expect(result.token_usage.input_tokens).to eq(10)
        expect(result.token_usage.output_tokens).to eq(8)
      end

      it "returns no tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls).to be_nil
      end
    end

    context "with multiple text blocks" do
      let(:response) do
        {
          "content" => [
            { "type" => "text", "text" => "First paragraph." },
            { "type" => "text", "text" => "Second paragraph." }
          ],
          "usage" => { "input_tokens" => 10, "output_tokens" => 8 }
        }
      end

      it "joins text blocks with newlines" do
        result = parser.parse_response(response)
        expect(result.content).to eq("First paragraph.\nSecond paragraph.")
      end
    end

    context "with tool use response" do
      let(:response) do
        {
          "content" => [
            { "type" => "text", "text" => "I'll search for that." },
            {
              "type" => "tool_use",
              "id" => "toolu_123",
              "name" => "search",
              "input" => { "query" => "Ruby programming" }
            }
          ],
          "usage" => { "input_tokens" => 20, "output_tokens" => 15 }
        }
      end

      it "extracts text content" do
        result = parser.parse_response(response)
        expect(result.content).to eq("I'll search for that.")
      end

      it "parses tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls).to be_an(Array)
        expect(result.tool_calls.length).to eq(1)
      end

      it "extracts tool call details" do
        result = parser.parse_response(response)
        tool_call = result.tool_calls.first

        expect(tool_call.id).to eq("toolu_123")
        expect(tool_call.name).to eq("search")
        expect(tool_call.arguments).to eq({ "query" => "Ruby programming" })
      end
    end

    context "with multiple tool calls" do
      let(:response) do
        {
          "content" => [
            { "type" => "tool_use", "id" => "t1", "name" => "search", "input" => { "q" => "a" } },
            { "type" => "tool_use", "id" => "t2", "name" => "fetch", "input" => { "url" => "b" } }
          ],
          "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
        }
      end

      it "parses all tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls.length).to eq(2)
        expect(result.tool_calls.map(&:name)).to eq(%w[search fetch])
      end
    end

    context "with tool use and no text" do
      let(:response) do
        {
          "content" => [
            { "type" => "tool_use", "id" => "t1", "name" => "calculate", "input" => { "expr" => "2+2" } }
          ],
          "usage" => {}
        }
      end

      it "returns empty content" do
        result = parser.parse_response(response)
        expect(result.content).to eq("")
      end

      it "still parses tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls.first.name).to eq("calculate")
      end
    end

    context "with API error response" do
      let(:response) do
        { "error" => { "message" => "Rate limit exceeded" } }
      end

      it "raises AgentGenerationError" do
        expect { parser.parse_response(response) }
          .to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
      end
    end
  end
end
