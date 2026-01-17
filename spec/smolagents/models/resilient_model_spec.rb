require "spec_helper"

RSpec.describe Smolagents::Models::ResilientModel do
  # Helper to drain events from Thread::Queue
  def drain_queue(queue)
    events = []
    while (event = begin
      queue.pop(true)
    rescue StandardError
      nil
    end)
      events << event
    end
    events
  end

  # Mock model for testing
  let(:mock_model_class) do
    Class.new do
      attr_reader :model_id, :generate_count

      def initialize(model_id: "test-model", should_fail: false, fail_count: 0)
        @model_id = model_id
        @should_fail = should_fail
        @fail_count = fail_count
        @generate_count = 0
        @current_failures = 0
      end

      def generate(_messages, **_kwargs)
        @generate_count += 1
        if @should_fail && @current_failures < @fail_count
          @current_failures += 1
          raise Faraday::TimeoutError, "timeout"
        end
        Smolagents::ChatMessage.assistant("Response from #{@model_id}")
      end
    end
  end

  let(:primary_model) { mock_model_class.new(model_id: "primary") }
  let(:backup_model) { mock_model_class.new(model_id: "backup") }
  let(:failing_model) { mock_model_class.new(model_id: "failing", should_fail: true, fail_count: 10) }

  describe "#initialize" do
    it "wraps a base model" do
      resilient = described_class.new(primary_model)
      expect(resilient.base_model).to eq(primary_model)
    end

    it "delegates model_id to base model" do
      resilient = described_class.new(primary_model)
      expect(resilient.model_id).to eq("primary")
    end

    it "accepts optional retry policy" do
      policy = Smolagents::Concerns::RetryPolicy.default
      resilient = described_class.new(primary_model, retry_policy: policy)
      expect(resilient.retry_policy).to eq(policy)
    end

    it "accepts fallback models" do
      resilient = described_class.new(primary_model, fallbacks: [backup_model])
      expect(resilient.fallbacks).to eq([backup_model])
    end
  end

  describe "#generate" do
    context "without resilience features" do
      it "delegates to base model" do
        resilient = described_class.new(primary_model)
        response = resilient.generate([])

        expect(response.content).to include("primary")
        expect(primary_model.generate_count).to eq(1)
      end
    end

    context "with retry policy" do
      let(:flaky_model) { mock_model_class.new(model_id: "flaky", should_fail: true, fail_count: 2) }

      it "retries on failure and succeeds" do
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 5, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(flaky_model, retry_policy: policy)
        response = resilient.generate([])

        expect(response.content).to include("flaky")
        expect(flaky_model.generate_count).to eq(3) # 2 failures + 1 success
      end

      it "raises after max retries" do
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 2, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(failing_model, retry_policy: policy)

        expect { resilient.generate([]) }.to raise_error(Faraday::TimeoutError)
      end
    end

    context "with fallback" do
      it "uses fallback when primary fails" do
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 1, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(failing_model, retry_policy: policy, fallbacks: [backup_model])
        response = resilient.generate([])

        expect(response.content).to include("backup")
      end

      it "does not use fallback when primary succeeds" do
        resilient = described_class.new(primary_model, fallbacks: [backup_model])
        resilient.generate([])

        expect(backup_model.generate_count).to eq(0)
      end
    end
  end

  describe "#with_retry" do
    it "configures retry policy" do
      resilient = described_class.new(primary_model)
                                 .with_retry(max_attempts: 5, backoff: :linear)

      expect(resilient.retry_policy.max_attempts).to eq(5)
      expect(resilient.retry_policy.backoff).to eq(:linear)
    end

    it "returns self for chaining" do
      resilient = described_class.new(primary_model)
      result = resilient.with_retry(max_attempts: 3)
      expect(result).to eq(resilient)
    end
  end

  describe "#with_fallback" do
    it "adds fallback model" do
      resilient = described_class.new(primary_model)
                                 .with_fallback(backup_model)

      expect(resilient.fallback_count).to eq(1)
    end

    it "allows chaining multiple fallbacks" do
      emergency = mock_model_class.new(model_id: "emergency")
      resilient = described_class.new(primary_model)
                                 .with_fallback(backup_model)
                                 .with_fallback(emergency)

      expect(resilient.fallback_count).to eq(2)
    end
  end

  describe "#prefer_healthy" do
    it "enables health-based routing" do
      resilient = described_class.new(primary_model)
                                 .prefer_healthy(cache_health_for: 10)

      expect(resilient.prefer_healthy?).to be true
      expect(resilient.health_cache_duration).to eq(10)
    end
  end

  describe "#model_chain" do
    it "returns base model plus fallbacks" do
      resilient = described_class.new(primary_model, fallbacks: [backup_model])

      expect(resilient.model_chain).to eq([primary_model, backup_model])
    end
  end

  describe "#reliability_config" do
    it "returns current configuration" do
      policy = Smolagents::Concerns::RetryPolicy.default
      resilient = described_class.new(primary_model,
                                      retry_policy: policy,
                                      fallbacks: [backup_model],
                                      prefer_healthy: true)

      config = resilient.reliability_config
      expect(config[:retry_policy]).to eq(policy)
      expect(config[:fallback_count]).to eq(1)
      expect(config[:prefer_healthy]).to be true
    end
  end

  describe "#reset_reliability" do
    it "clears all configuration" do
      resilient = described_class.new(primary_model)
                                 .with_retry(max_attempts: 5)
                                 .with_fallback(backup_model)
                                 .prefer_healthy
                                 .reset_reliability

      expect(resilient.retry_policy).to be_nil
      expect(resilient.fallback_count).to eq(0)
      expect(resilient.prefer_healthy?).to be false
    end
  end

  describe "event subscriptions" do
    describe "#on_failover" do
      it "subscribes to failover events" do
        events = []
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 1, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(failing_model, retry_policy: policy, fallbacks: [backup_model])
        resilient.on_failover { |e| events << e }

        resilient.generate([])

        expect(events.size).to eq(1)
        expect(events.first).to be_a(Smolagents::Events::FailoverOccurred)
        expect(events.first.from_model_id).to eq("failing")
        expect(events.first.to_model_id).to eq("backup")
      end
    end

    describe "#on_retry" do
      let(:flaky_model) { mock_model_class.new(model_id: "flaky", should_fail: true, fail_count: 2) }

      it "subscribes to retry events" do
        retry_events = []
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 5, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(flaky_model, retry_policy: policy)
        resilient.on_retry { |e| retry_events << e }

        resilient.generate([])

        expect(retry_events.size).to eq(2) # 2 retries before success
        expect(retry_events.first).to be_a(Smolagents::Events::RetryRequested)
      end
    end

    describe "#on_recovery" do
      let(:flaky_model) { mock_model_class.new(model_id: "flaky", should_fail: true, fail_count: 1) }

      it "subscribes to recovery events" do
        recovered = false
        recovery_model_id = nil
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 3, base_interval: 0.01, max_interval: 0.1,
          backoff: :constant, jitter: 0.0,
          retryable_errors: Smolagents::Concerns::ErrorClassification::RETRIABLE_ERRORS
        )
        resilient = described_class.new(flaky_model, retry_policy: policy)
        resilient.on_recovery do |e|
          recovered = true
          recovery_model_id = e.model_id
        end

        resilient.generate([])

        expect(recovered).to be true
        expect(recovery_model_id).to eq("flaky")
      end
    end
  end

  describe "delegation" do
    let(:model_with_methods) do
      Class.new(mock_model_class) do
        def custom_method
          "custom result"
        end
      end.new(model_id: "with-methods")
    end

    it "delegates unknown methods to base model" do
      resilient = described_class.new(model_with_methods)
      expect(resilient.custom_method).to eq("custom result")
    end

    it "responds to base model methods" do
      resilient = described_class.new(model_with_methods)
      expect(resilient.respond_to?(:custom_method)).to be true
    end
  end
end
