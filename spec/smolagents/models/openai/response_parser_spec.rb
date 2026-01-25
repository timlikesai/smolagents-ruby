require "spec_helper"

RSpec.describe Smolagents::Models::OpenAI::ResponseParser do
  let(:parser_class) do
    Class.new { include Smolagents::Models::OpenAI::ResponseParser }
  end
  let(:parser) { parser_class.new }

  describe "#parse_response" do
    context "with simple text response" do
      let(:response) do
        {
          "choices" => [{ "message" => { "content" => "Hello, world!" } }],
          "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
        }
      end

      it "extracts content" do
        result = parser.parse_response(response)
        expect(result.content).to eq("Hello, world!")
      end

      it "parses token usage" do
        result = parser.parse_response(response)
        expect(result.token_usage.input_tokens).to eq(10)
        expect(result.token_usage.output_tokens).to eq(5)
      end

      it "returns no tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls).to be_nil
      end
    end

    context "with tool call response" do
      let(:response) do
        {
          "choices" => [{
            "message" => {
              "content" => "Let me search for that.",
              "tool_calls" => [{
                "id" => "call_123",
                "function" => {
                  "name" => "search",
                  "arguments" => '{"query": "Ruby programming"}'
                }
              }]
            }
          }],
          "usage" => { "prompt_tokens" => 20, "completion_tokens" => 15 }
        }
      end

      it "extracts content" do
        result = parser.parse_response(response)
        expect(result.content).to eq("Let me search for that.")
      end

      it "parses tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls).to be_an(Array)
        expect(result.tool_calls.length).to eq(1)
      end

      it "extracts tool call details" do
        result = parser.parse_response(response)
        tool_call = result.tool_calls.first

        expect(tool_call.id).to eq("call_123")
        expect(tool_call.name).to eq("search")
        expect(tool_call.arguments).to eq({ "query" => "Ruby programming" })
      end
    end

    context "with multiple tool calls" do
      let(:response) do
        {
          "choices" => [{
            "message" => {
              "content" => nil,
              "tool_calls" => [
                { "id" => "call_1", "function" => { "name" => "search", "arguments" => '{"q": "a"}' } },
                { "id" => "call_2", "function" => { "name" => "fetch", "arguments" => '{"url": "b"}' } }
              ]
            }
          }],
          "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
        }
      end

      it "parses all tool calls" do
        result = parser.parse_response(response)
        expect(result.tool_calls.length).to eq(2)
        expect(result.tool_calls.map(&:name)).to eq(%w[search fetch])
      end
    end

    context "with malformed JSON arguments" do
      let(:response) do
        {
          "choices" => [{
            "message" => {
              "tool_calls" => [{
                "id" => "call_bad",
                "function" => { "name" => "test", "arguments" => "not valid json" }
              }]
            }
          }],
          "usage" => {}
        }
      end

      it "returns error indicator instead of raising" do
        result = parser.parse_response(response)
        tool_call = result.tool_calls.first

        expect(tool_call.arguments).to have_key("_parse_error")
        expect(tool_call.arguments).to have_key("_raw")
      end
    end

    context "with API error response" do
      let(:response) do
        { "error" => { "message" => "Invalid API key" } }
      end

      it "raises AgentGenerationError" do
        expect { parser.parse_response(response) }
          .to raise_error(Smolagents::AgentGenerationError, /Invalid API key/)
      end
    end
  end
end
