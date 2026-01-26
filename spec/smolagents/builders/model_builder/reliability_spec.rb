require "spec_helper"

RSpec.describe Smolagents::Builders::ModelBuilderReliability do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::ModelBuilderReliability

      def self.create
        new(configuration: { fallbacks: [] })
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end

      def check_frozen!
        raise FrozenError if configuration[:__frozen__]
      end

      def freeze!
        with_config(__frozen__: true)
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#with_health_check" do
    it "enables health checking" do
      result = builder.with_health_check

      expect(result.configuration[:health_check]).not_to be_nil
    end

    it "returns new builder instance" do
      result = builder.with_health_check

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end

    it "sets default cache_for to 5" do
      result = builder.with_health_check

      expect(result.configuration[:health_check][:cache_for]).to eq(5)
    end

    it "accepts custom cache_for duration" do
      result = builder.with_health_check(cache_for: 30)

      expect(result.configuration[:health_check][:cache_for]).to eq(30)
    end

    it "stores thresholds" do
      result = builder.with_health_check(latency: 500, error_rate: 0.1)

      expect(result.configuration[:health_check][:thresholds]).to include(:latency, :error_rate)
    end

    it "preserves immutability" do
      original_config = builder.configuration.dup
      builder.with_health_check

      expect(builder.configuration).to eq(original_config)
    end
  end

  describe "#with_retry" do
    it "enables retry policy" do
      result = builder.with_retry

      expect(result.configuration[:retry_policy]).not_to be_nil
    end

    it "sets default max_attempts to 3" do
      result = builder.with_retry

      expect(result.configuration[:retry_policy][:max_attempts]).to eq(3)
    end

    it "accepts custom max_attempts" do
      result = builder.with_retry(max_attempts: 5)

      expect(result.configuration[:retry_policy][:max_attempts]).to eq(5)
    end

    it "sets default backoff to :exponential" do
      result = builder.with_retry

      expect(result.configuration[:retry_policy][:backoff]).to eq(:exponential)
    end

    it "accepts custom backoff strategy" do
      %i[exponential linear constant].each do |strategy|
        result = builder.with_retry(backoff: strategy)

        expect(result.configuration[:retry_policy][:backoff]).to eq(strategy)
      end
    end

    it "sets default base_interval to 1.0" do
      result = builder.with_retry

      expect(result.configuration[:retry_policy][:base_interval]).to eq(1.0)
    end

    it "accepts custom base_interval" do
      result = builder.with_retry(base_interval: 2.5)

      expect(result.configuration[:retry_policy][:base_interval]).to eq(2.5)
    end

    it "sets default max_interval to 30.0" do
      result = builder.with_retry

      expect(result.configuration[:retry_policy][:max_interval]).to eq(30.0)
    end

    it "accepts custom max_interval" do
      result = builder.with_retry(max_interval: 60.0)

      expect(result.configuration[:retry_policy][:max_interval]).to eq(60.0)
    end

    it "supports full configuration" do
      result = builder.with_retry(
        max_attempts: 5,
        backoff: :linear,
        base_interval: 0.5,
        max_interval: 15.0
      )

      policy = result.configuration[:retry_policy]
      expect(policy[:max_attempts]).to eq(5)
      expect(policy[:backoff]).to eq(:linear)
      expect(policy[:base_interval]).to eq(0.5)
      expect(policy[:max_interval]).to eq(15.0)
    end

    it "returns new builder instance" do
      result = builder.with_retry

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end
  end

  describe "#with_fallback" do
    it "adds fallback with block" do
      fallback_block = proc { "fallback_model" }
      result = builder.with_fallback(&fallback_block)

      expect(result.configuration[:fallbacks]).to include(fallback_block)
    end

    it "adds fallback with instance" do
      fallback_model = instance_double(Smolagents::Models::Model)
      result = builder.with_fallback(fallback_model)

      expect(result.configuration[:fallbacks]).to include(fallback_model)
    end

    it "returns new builder instance" do
      result = builder.with_fallback { "model" }

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end

    it "accumulates multiple fallbacks" do
      r1 = builder.with_fallback { "fallback1" }
      r2 = r1.with_fallback { "fallback2" }

      expect(r2.configuration[:fallbacks].size).to eq(2)
    end

    it "preserves fallback order" do
      fallback1 = "fallback1"
      fallback2 = "fallback2"

      result = builder.with_fallback(fallback1).with_fallback(fallback2)

      fallbacks = result.configuration[:fallbacks]
      expect(fallbacks[0]).to eq(fallback1)
      expect(fallbacks[1]).to eq(fallback2)
    end

    it "prefers model instance over block argument" do
      fallback_model = instance_double(Smolagents::Models::Model)

      # Implementation uses `model || block` - model takes precedence
      result = builder.with_fallback(fallback_model) { "block_fallback" }

      expect(result.configuration[:fallbacks].size).to eq(1)
      expect(result.configuration[:fallbacks].first).to eq(fallback_model)
    end
  end

  describe "#with_circuit_breaker" do
    it "enables circuit breaker" do
      result = builder.with_circuit_breaker

      expect(result.configuration[:circuit_breaker]).not_to be_nil
    end

    it "sets default threshold to 5" do
      result = builder.with_circuit_breaker

      expect(result.configuration[:circuit_breaker][:threshold]).to eq(5)
    end

    it "accepts custom threshold" do
      result = builder.with_circuit_breaker(threshold: 3)

      expect(result.configuration[:circuit_breaker][:threshold]).to eq(3)
    end

    it "sets default reset_after to 60" do
      result = builder.with_circuit_breaker

      expect(result.configuration[:circuit_breaker][:reset_after]).to eq(60)
    end

    it "accepts custom reset_after" do
      result = builder.with_circuit_breaker(reset_after: 30)

      expect(result.configuration[:circuit_breaker][:reset_after]).to eq(30)
    end

    it "supports full configuration" do
      result = builder.with_circuit_breaker(threshold: 10, reset_after: 120)

      config = result.configuration[:circuit_breaker]
      expect(config[:threshold]).to eq(10)
      expect(config[:reset_after]).to eq(120)
    end

    it "returns new builder instance" do
      result = builder.with_circuit_breaker

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end
  end

  describe "#with_queue" do
    it "enables request queueing" do
      result = builder.with_queue

      expect(result.configuration[:queue]).not_to be_nil
    end

    it "creates queue config hash" do
      result = builder.with_queue

      expect(result.configuration[:queue]).to be_a(Hash)
    end

    it "sets max_depth to nil by default (unlimited)" do
      result = builder.with_queue

      expect(result.configuration[:queue][:max_depth]).to be_nil
    end

    it "accepts custom max_depth" do
      result = builder.with_queue(max_depth: 100)

      expect(result.configuration[:queue][:max_depth]).to eq(100)
    end

    it "accepts zero max_depth" do
      result = builder.with_queue(max_depth: 0)

      expect(result.configuration[:queue][:max_depth]).to eq(0)
    end

    it "accepts large max_depth" do
      result = builder.with_queue(max_depth: 10_000)

      expect(result.configuration[:queue][:max_depth]).to eq(10_000)
    end

    it "ignores extra keyword arguments" do
      # Unknown kwargs should be ignored, not raise error
      result = builder.with_queue(max_depth: 50, unknown: "ignored")

      expect(result.configuration[:queue][:max_depth]).to eq(50)
    end

    it "returns new builder instance" do
      result = builder.with_queue

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end
  end

  describe "#prefer_healthy" do
    it "enables prefer_healthy flag" do
      result = builder.prefer_healthy

      expect(result.configuration[:prefer_healthy]).to be true
    end

    it "returns new builder instance" do
      result = builder.prefer_healthy

      expect(result).not_to equal(builder)
      expect(result).to be_a(test_builder_class)
    end

    it "preserves immutability" do
      original_config = builder.configuration.dup
      builder.prefer_healthy

      expect(builder.configuration).to eq(original_config)
    end
  end

  describe "method chaining" do
    it "supports chaining reliability methods" do
      result = builder
               .with_health_check(cache_for: 10)
               .with_retry(max_attempts: 5)
               .with_circuit_breaker(threshold: 3)
               .with_queue(max_depth: 100)
               .prefer_healthy

      expect(result.configuration[:health_check]).not_to be_nil
      expect(result.configuration[:retry_policy]).not_to be_nil
      expect(result.configuration[:circuit_breaker]).not_to be_nil
      expect(result.configuration[:queue]).not_to be_nil
      expect(result.configuration[:prefer_healthy]).to be true
    end

    it "can call same method multiple times" do
      r1 = builder.with_health_check(cache_for: 5)
      r2 = r1.with_health_check(cache_for: 10)

      expect(r1.configuration[:health_check][:cache_for]).to eq(5)
      expect(r2.configuration[:health_check][:cache_for]).to eq(10)
    end

    it "can add multiple fallbacks" do
      r1 = builder.with_fallback { "fallback1" }
      r2 = r1.with_fallback { "fallback2" }
      r3 = r2.with_fallback { "fallback3" }

      expect(r3.configuration[:fallbacks].size).to eq(3)
    end
  end

  # NOTE: The ModelBuilderReliability module doesn't call check_frozen!
  # in its methods, so frozen behavior is not enforced at this level.
  # Frozen checks are typically done in the main builder that includes
  # this concern.

  describe "configuration preservation" do
    it "preserves other config when adding reliability options" do
      base = test_builder_class.new(configuration: { model_id: "gpt-4" })

      result = base.with_health_check

      expect(result.configuration[:model_id]).to eq("gpt-4")
    end

    it "preserves multiple config values" do
      base = test_builder_class.new(configuration: { model_id: "gpt-4", temperature: 0.7 })

      result = base.with_retry.with_circuit_breaker

      expect(result.configuration[:model_id]).to eq("gpt-4")
      expect(result.configuration[:temperature]).to eq(0.7)
    end
  end
end
