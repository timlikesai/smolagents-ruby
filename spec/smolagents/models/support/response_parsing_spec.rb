require "spec_helper"

RSpec.describe Smolagents::Models::ModelSupport::ResponseParsing do
  let(:test_class) do
    Class.new do
      include Smolagents::Models::ModelSupport::ResponseParsing
    end
  end

  let(:parser) { test_class.new }

  describe "#check_response_error" do
    context "when response has no error" do
      let(:response) { { "content" => "Hello" } }

      it "returns nil" do
        expect(parser.check_response_error(response, provider: "Test")).to be_nil
      end
    end

    context "when response has error" do
      let(:response) { { "error" => { "message" => "Rate limit exceeded" } } }

      it "raises AgentGenerationError with provider context" do
        expect { parser.check_response_error(response, provider: "Test") }
          .to raise_error(Smolagents::AgentGenerationError, "Test error: Rate limit exceeded")
      end
    end
  end

  describe "#parse_chat_response" do
    context "with valid response" do
      let(:response) { { "content" => "test" } }
      let(:tool_calls) { [Smolagents::ToolCall.new(id: "1", name: "search", arguments: {})] }
      let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5) }

      it "builds ChatMessage from extractor results" do
        result = parser.parse_chat_response(response, provider: "Test") do |_resp|
          ["Hello world", tool_calls, token_usage]
        end

        expect(result).to be_a(Smolagents::ChatMessage)
        expect(result.content).to eq("Hello world")
        expect(result.tool_calls).to eq(tool_calls)
        expect(result.token_usage).to eq(token_usage)
        expect(result.raw).to eq(response)
      end
    end

    context "with error response" do
      let(:response) { { "error" => { "message" => "API error" } } }

      it "raises before extracting" do
        expect do
          parser.parse_chat_response(response, provider: "Test") do |_resp|
            raise "Should not reach here"
          end
        end.to raise_error(Smolagents::AgentGenerationError)
      end
    end
  end

  describe "#parse_token_usage" do
    context "with valid usage" do
      let(:usage) { { "in" => 100, "out" => 50 } }

      it "returns TokenUsage with mapped keys" do
        result = parser.parse_token_usage(usage, input_key: "in", output_key: "out")

        expect(result).to be_a(Smolagents::TokenUsage)
        expect(result.input_tokens).to eq(100)
        expect(result.output_tokens).to eq(50)
      end
    end

    context "with nil usage" do
      it "returns nil" do
        expect(parser.parse_token_usage(nil, input_key: "in", output_key: "out")).to be_nil
      end
    end
  end
end
