# frozen_string_literal: true

require "thor"
require "smolagents"
require "smolagents/cli/model_builder"

RSpec.describe Smolagents::CLI::ModelBuilder do
  let(:test_class) do
    Class.new do
      include Smolagents::CLI::ModelBuilder
    end
  end

  let(:builder) { test_class.new }

  describe "PROVIDERS" do
    it "includes openai provider" do
      expect(described_class::PROVIDERS).to have_key(:openai)
    end

    it "includes anthropic provider" do
      expect(described_class::PROVIDERS).to have_key(:anthropic)
    end

    it "is frozen" do
      expect(described_class::PROVIDERS).to be_frozen
    end
  end

  describe "#build_model" do
    it "builds OpenAI model for openai provider" do
      model = builder.build_model(provider: "openai", model_id: "gpt-4", api_key: "test-key")
      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "builds Anthropic model for anthropic provider" do
      model = builder.build_model(provider: "anthropic", model_id: "claude-3", api_key: "test-key")
      expect(model).to be_a(Smolagents::AnthropicModel)
    end

    it "accepts api_base when provided" do
      # api_base is passed to the underlying OpenAI client, not stored on the model
      expect do
        builder.build_model(provider: "openai", model_id: "local", api_key: "key", api_base: "http://localhost:1234")
      end.not_to raise_error
    end

    it "raises Thor::Error for unknown provider" do
      expect do
        builder.build_model(provider: "unknown", model_id: "model")
      end.to raise_error(Thor::Error, /Unknown provider/)
    end
  end
end
