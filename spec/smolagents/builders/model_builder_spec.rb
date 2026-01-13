require "spec_helper"

RSpec.describe Smolagents::Builders::ModelBuilder do
  # Mock model for testing
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

  before do
    # Stub the model class lookup
    allow(Smolagents).to receive(:const_get).with("OpenAIModel").and_return(mock_model_class)
    allow(Smolagents).to receive(:const_get).with("AnthropicModel").and_return(mock_model_class)
  end

  describe "#id" do
    it "sets the model ID" do
      builder = described_class.create(:openai).id("gpt-4")
      expect(builder.config[:model_id]).to eq("gpt-4")
    end

    it "returns a new builder instance (immutable)" do
      builder = described_class.create(:openai)
      new_builder = builder.id("gpt-4")

      expect(new_builder).not_to eq(builder)
      expect(new_builder).to be_a(described_class)
      expect(new_builder.config[:model_id]).to eq("gpt-4")
      expect(builder.config[:model_id]).to be_nil
    end
  end

  describe "#api_key" do
    it "sets the API key" do
      builder = described_class.create(:openai).api_key("sk-test")
      expect(builder.config[:api_key]).to eq("sk-test")
    end
  end

  describe "#endpoint" do
    it "sets the API base URL" do
      builder = described_class.create(:openai).endpoint("http://localhost:8080/v1")
      expect(builder.config[:api_base]).to eq("http://localhost:8080/v1")
    end
  end

  describe "#temperature" do
    it "sets the temperature" do
      builder = described_class.create(:openai).temperature(0.7)
      expect(builder.config[:temperature]).to eq(0.7)
    end
  end

  describe "#timeout" do
    it "sets the timeout" do
      builder = described_class.create(:openai).timeout(30)
      expect(builder.config[:timeout]).to eq(30)
    end
  end

  describe "#max_tokens" do
    it "sets max tokens" do
      builder = described_class.create(:openai).max_tokens(4096)
      expect(builder.config[:max_tokens]).to eq(4096)
    end
  end

  describe "#at" do
    it "configures host and port" do
      builder = described_class.create(:openai).at(host: "myserver", port: 9000)
      expect(builder.config[:api_base]).to eq("http://myserver:9000/v1")
      expect(builder.config[:api_key]).to eq("not-needed")
    end
  end

  describe "local server types" do
    it "configures lm_studio with default port" do
      builder = described_class.create(:lm_studio)
      expect(builder.config[:api_base]).to eq("http://localhost:1234/v1")
      expect(builder.config[:api_key]).to eq("not-needed")
    end

    it "configures ollama with default port" do
      builder = described_class.create(:ollama)
      expect(builder.config[:api_base]).to eq("http://localhost:11434/v1")
    end

    it "configures llama_cpp with default port" do
      builder = described_class.create(:llama_cpp)
      expect(builder.config[:api_base]).to eq("http://localhost:8080/v1")
    end

    it "configures vllm with default port" do
      builder = described_class.create(:vllm)
      expect(builder.config[:api_base]).to eq("http://localhost:8000/v1")
    end
  end

  describe "#with_health_check" do
    it "enables health checking" do
      builder = described_class.create(:openai).with_health_check
      expect(builder.config[:health_check]).to include(cache_for: 5)
    end

    it "accepts custom cache duration" do
      builder = described_class.create(:openai).with_health_check(cache_for: 30)
      expect(builder.config[:health_check][:cache_for]).to eq(30)
    end
  end

  describe "#with_retry" do
    it "configures retry policy" do
      builder = described_class.create(:openai).with_retry(max_attempts: 5)
      expect(builder.config[:retry_policy][:max_attempts]).to eq(5)
    end

    it "has default values" do
      builder = described_class.create(:openai).with_retry
      policy = builder.config[:retry_policy]
      expect(policy[:max_attempts]).to eq(3)
      expect(policy[:backoff]).to eq(:exponential)
      expect(policy[:base_interval]).to eq(1.0)
      expect(policy[:max_interval]).to eq(30.0)
    end
  end

  describe "#with_fallback" do
    it "adds a fallback model" do
      backup = mock_model_class.new(model_id: "backup")
      builder = described_class.create(:openai).with_fallback(backup)
      expect(builder.config[:fallbacks]).to include(backup)
    end

    it "accepts a block for lazy instantiation" do
      builder = described_class.create(:openai).with_fallback { mock_model_class.new(model_id: "lazy") }
      expect(builder.config[:fallbacks].first).to be_a(Proc)
    end

    it "allows multiple fallbacks" do
      builder = described_class.create(:openai)
                               .with_fallback { mock_model_class.new(model_id: "first") }
                               .with_fallback { mock_model_class.new(model_id: "second") }
      expect(builder.config[:fallbacks].size).to eq(2)
    end
  end

  describe "#with_circuit_breaker" do
    it "configures circuit breaker" do
      builder = described_class.create(:openai).with_circuit_breaker(threshold: 3, reset_after: 30)
      expect(builder.config[:circuit_breaker]).to eq(threshold: 3, reset_after: 30)
    end
  end

  describe "#with_queue" do
    it "configures request queue" do
      builder = described_class.create(:openai).with_queue(max_depth: 10)
      expect(builder.config[:queue]).to eq(max_depth: 10)
    end
  end

  describe "#prefer_healthy" do
    it "sets prefer_healthy flag" do
      builder = described_class.create(:openai).prefer_healthy
      expect(builder.config[:prefer_healthy]).to be true
    end
  end

  describe "callbacks" do
    it "registers failover callback" do
      builder = described_class.create(:openai).on_failover { |event| puts event }
      callback = builder.config[:callbacks].find { |c| c[:type] == :failover }
      expect(callback[:handler]).to be_a(Proc)
    end

    it "registers error callback" do
      builder = described_class.create(:openai).on_error { |e, _attempt, _model| puts e }
      callback = builder.config[:callbacks].find { |c| c[:type] == :error }
      expect(callback[:handler]).to be_a(Proc)
    end

    it "registers recovery callback" do
      builder = described_class.create(:openai).on_recovery { |model, _attempt| puts model }
      callback = builder.config[:callbacks].find { |c| c[:type] == :recovery }
      expect(callback[:handler]).to be_a(Proc)
    end

    it "registers model_change callback" do
      builder = described_class.create(:openai).on_model_change { |old, new| puts "#{old} -> #{new}" }
      callback = builder.config[:callbacks].find { |c| c[:type] == :model_change }
      expect(callback[:handler]).to be_a(Proc)
    end

    it "registers queue_wait callback" do
      builder = described_class.create(:openai).on_queue_wait { |pos, _elapsed| puts pos }
      callback = builder.config[:callbacks].find { |c| c[:type] == :queue_wait }
      expect(callback[:handler]).to be_a(Proc)
    end
  end

  describe "#build" do
    it "creates a model instance" do
      model = described_class.create(:openai)
                             .id("gpt-4")
                             .api_key("sk-test")
                             .build

      expect(model.model_id).to eq("gpt-4")
      expect(model.api_key).to eq("sk-test")
    end

    it "applies all configuration" do
      model = described_class.create(:openai)
                             .id("gpt-4")
                             .temperature(0.5)
                             .max_tokens(2048)
                             .timeout(60)
                             .build

      expect(model.temperature).to eq(0.5)
      expect(model.max_tokens).to eq(2048)
      expect(model.timeout).to eq(60)
    end

    it "extends model with health check when configured" do
      model = described_class.create(:openai)
                             .id("gpt-4")
                             .with_health_check
                             .build

      expect(model.singleton_class.include?(Smolagents::Concerns::ModelHealth)).to be true
    end

    it "extends model with request queue when configured" do
      model = described_class.create(:openai)
                             .id("gpt-4")
                             .with_queue(max_depth: 10)
                             .build

      expect(model.singleton_class.include?(Smolagents::Concerns::RequestQueue)).to be true
      expect(model.queue_enabled?).to be true
    end

    it "extends model with reliability when retry configured" do
      model = described_class.create(:openai)
                             .id("gpt-4")
                             .with_retry(max_attempts: 3)
                             .build

      expect(model.singleton_class.include?(Smolagents::Concerns::ModelReliability)).to be true
    end

    it "wraps existing model" do
      existing = mock_model_class.new(model_id: "existing")
      model = described_class.create(existing)
                             .with_health_check
                             .build

      expect(model).to eq(existing)
      expect(model.singleton_class.include?(Smolagents::Concerns::ModelHealth)).to be true
    end
  end

  describe "#inspect" do
    it "shows configuration summary" do
      builder = described_class.create(:openai)
                               .id("gpt-4")
                               .with_health_check
                               .with_retry(max_attempts: 5)
                               .with_fallback { mock_model_class.new(model_id: "backup") }

      output = builder.inspect
      expect(output).to include("ModelBuilder")
      expect(output).to include("type=openai")
      expect(output).to include("model_id=gpt-4")
      expect(output).to include("health_check")
      expect(output).to include("retry=5")
      expect(output).to include("fallbacks=1")
    end
  end

  describe "chaining" do
    it "supports fluent chaining of all methods" do
      builder = described_class.create(:lm_studio)
                               .id("local-model")
                               .temperature(0.7)
                               .timeout(30)
                               .with_health_check(cache_for: 10)
                               .with_retry(max_attempts: 3)
                               .with_fallback { mock_model_class.new(model_id: "backup") }
                               .with_queue(max_depth: 10)
                               .prefer_healthy
                               .on_failover { |e| puts e }
                               .on_error { |e, _a, _m| puts e }
                               .on_recovery { |m, _a| puts m }
                               .on_model_change { |o, n| puts "#{o} -> #{n}" }

      expect(builder).to be_a(described_class)

      model = builder.build
      expect(model.model_id).to eq("local-model")
    end
  end
end
