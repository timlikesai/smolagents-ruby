require "spec_helper"

RSpec.describe Smolagents::Models::ModelSupport::RequestBuilding do
  let(:test_class) do
    Class.new do
      include Smolagents::Models::ModelSupport::RequestBuilding

      attr_reader :model_id, :temperature, :max_tokens

      def initialize(model_id:, temperature:, max_tokens:)
        @model_id = model_id
        @temperature = temperature
        @max_tokens = max_tokens
      end

      def format_messages(messages) = messages.map(&:to_h)
      def format_tools(tools) = tools.map { |t| { name: t.name } }
    end
  end

  let(:builder) { test_class.new(model_id: "test-model", temperature: 0.7, max_tokens: 1000) }

  describe "#build_base_params" do
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    context "with defaults" do
      it "builds params with model and formatted messages" do
        result = builder.build_base_params(messages:, temperature: nil, max_tokens: nil)

        expect(result[:model]).to eq("test-model")
        expect(result[:messages]).to eq([messages.first.to_h])
        expect(result[:temperature]).to eq(0.7)
        expect(result[:max_tokens]).to eq(1000)
        expect(result).not_to have_key(:tools)
      end
    end

    context "with overrides" do
      it "uses override values" do
        result = builder.build_base_params(messages:, temperature: 0.5, max_tokens: 500)

        expect(result[:temperature]).to eq(0.5)
        expect(result[:max_tokens]).to eq(500)
      end
    end

    context "with tools" do
      let(:tool) do
        instance_double(Smolagents::Tool, name: "search", description: "Search", inputs: {})
      end

      it "includes formatted tools" do
        result = builder.build_base_params(messages:, temperature: nil, max_tokens: nil, tools: [tool])

        expect(result[:tools]).to eq([{ name: "search" }])
      end
    end
  end

  describe "#merge_params" do
    it "merges and compacts params" do
      base = { model: "test", messages: [] }
      extras = { stop: ["END"], response_format: nil }

      result = builder.merge_params(base, extras)

      expect(result).to eq({ model: "test", messages: [], stop: ["END"] })
    end
  end
end
