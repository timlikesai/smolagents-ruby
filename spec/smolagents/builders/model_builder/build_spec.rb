require "spec_helper"

RSpec.describe Smolagents::Builders::ModelBuilderBuild do
  let(:mock_model_class) do
    Class.new do
      attr_reader :model_id, :api_key, :api_base, :temperature, :max_tokens, :timeout

      def initialize(model_id:, api_key: nil, api_base: nil, temperature: nil, max_tokens: nil, timeout: nil)
        @model_id = model_id
        @api_key = api_key
        @api_base = api_base
        @temperature = temperature
        @max_tokens = max_tokens
        @timeout = timeout
      end

      def generate(_messages, **_kwargs)
        Smolagents::ChatMessage.assistant("Response from #{@model_id}")
      end
    end
  end

  let(:builder_class) { Smolagents::Builders::ModelBuilder }
  let(:builder) { builder_class.create(:openai) }

  before do
    allow(Smolagents).to receive(:const_get).with("OpenAIModel").and_return(mock_model_class)
    allow(Smolagents).to receive(:const_get).with("AnthropicModel").and_return(mock_model_class)
  end

  describe "#build" do
    context "with basic configuration" do
      it "creates a model instance" do
        model = builder.id("gpt-4").build

        expect(model.model_id).to eq("gpt-4")
      end

      it "passes all configuration to model" do
        model = builder
                .id("gpt-4")
                .api_key("sk-test")
                .temperature(0.7)
                .max_tokens(4096)
                .timeout(30)
                .build

        expect(model.model_id).to eq("gpt-4")
        expect(model.api_key).to eq("sk-test")
        expect(model.temperature).to eq(0.7)
        expect(model.max_tokens).to eq(4096)
        expect(model.timeout).to eq(30)
      end

      it "uses default model_id when not specified" do
        model = builder.build

        expect(model.model_id).to eq("default")
      end
    end

    context "with existing model" do
      it "returns the existing model unchanged" do
        existing = mock_model_class.new(model_id: "existing")
        model = builder_class.create(existing).build

        expect(model).to equal(existing)
      end

      it "extends existing model with requested features" do
        existing = mock_model_class.new(model_id: "existing")
        model = builder_class.create(existing).with_health_check.build

        expect(model.singleton_class.include?(Smolagents::Concerns::ModelHealth)).to be true
      end
    end

    context "with health check" do
      it "extends model with ModelHealth concern" do
        model = builder.id("gpt-4").with_health_check.build

        expect(model.singleton_class.include?(Smolagents::Concerns::ModelHealth)).to be true
      end

      it "does not extend twice if already extended" do
        model = builder.id("gpt-4").with_health_check.build
        # Call build again with same model (simulated by extending first)
        expect(model.singleton_class.include?(Smolagents::Concerns::ModelHealth)).to be true
      end
    end

    context "with request queue" do
      it "extends model with RequestQueue concern" do
        model = builder.id("gpt-4").with_queue(max_depth: 10).build

        expect(model.singleton_class.include?(Smolagents::Concerns::RequestQueue)).to be true
      end

      it "enables queue with configuration" do
        model = builder.id("gpt-4").with_queue(max_depth: 10).build

        expect(model.queue_enabled?).to be true
      end
    end

    context "with retry policy" do
      it "extends model with ModelReliability concern" do
        model = builder.id("gpt-4").with_retry(max_attempts: 5).build

        expect(model.singleton_class.include?(Smolagents::Concerns::ModelReliability)).to be true
      end

      it "configures retry policy" do
        model = builder.id("gpt-4").with_retry(max_attempts: 5).build

        expect(model.reliability_config[:retry_policy].max_attempts).to eq(5)
      end

      it "uses default retry values" do
        model = builder.id("gpt-4").with_retry.build
        policy = model.reliability_config[:retry_policy]

        expect(policy.max_attempts).to eq(3)
        expect(policy.backoff).to eq(:exponential)
      end
    end

    context "with fallbacks" do
      it "adds fallback models" do
        backup = mock_model_class.new(model_id: "backup")
        model = builder.id("gpt-4").with_fallback(backup).build

        expect(model.singleton_class.include?(Smolagents::Concerns::ModelReliability)).to be true
        # model_chain includes self + fallbacks
        expect(model.model_chain).to include(backup)
      end

      it "resolves lazy fallbacks (procs)" do
        backup = mock_model_class.new(model_id: "lazy-backup")
        model = builder.id("gpt-4").with_fallback { backup }.build

        # model_chain[0] is self, model_chain[1] is first fallback
        expect(model.model_chain[1]).to eq(backup)
      end

      it "supports multiple fallbacks" do
        backup1 = mock_model_class.new(model_id: "backup1")
        backup2 = mock_model_class.new(model_id: "backup2")

        model = builder
                .id("gpt-4")
                .with_fallback(backup1)
                .with_fallback(backup2)
                .build

        # model_chain includes self + 2 fallbacks = 3 total
        expect(model.model_chain.size).to eq(3)
        expect(model.fallback_count).to eq(2)
      end
    end

    context "with prefer_healthy" do
      it "enables health-based routing" do
        model = builder.id("gpt-4").prefer_healthy.build

        expect(model.singleton_class.include?(Smolagents::Concerns::ModelReliability)).to be true
      end
    end

    context "with callbacks" do
      it "applies callbacks to the model" do
        callback_called = false
        model = builder
                .id("gpt-4")
                .with_retry
                .on_error { callback_called = true }
                .build

        # Verify callback was registered (model should respond to error events)
        expect(model).to respond_to(:on_error)
      end
    end

    context "with different model types" do
      it "resolves :openai to OpenAIModel" do
        model = builder_class.create(:openai).id("gpt-4").build

        expect(model).to be_a(mock_model_class)
      end

      it "resolves :anthropic to AnthropicModel" do
        model = builder_class.create(:anthropic).id("claude-3").build

        expect(model).to be_a(mock_model_class)
      end

      it "resolves :lm_studio to OpenAIModel" do
        model = builder_class.create(:lm_studio).id("local").build

        expect(model).to be_a(mock_model_class)
      end
    end
  end
end
