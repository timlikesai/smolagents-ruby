require "spec_helper"

RSpec.describe Smolagents::Concerns::ModelReliability do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ModelReliability

      attr_reader :model_id, :generate_count

      def initialize(model_id: "primary", should_fail: false, fail_count: 0)
        @model_id = model_id
        @should_fail = should_fail
        @fail_count = fail_count
        @generate_count = 0
        @current_failures = 0
        setup_consumer
      end

      def generate(_messages, **_kwargs)
        @generate_count += 1
        if @should_fail && @current_failures < @fail_count
          @current_failures += 1
          raise Faraday::TimeoutError, "timeout"
        end
        Smolagents::ChatMessage.assistant("Response from #{@model_id}")
      end

      alias_method :original_generate, :generate
    end
  end

  let(:primary) { test_class.new(model_id: "primary") }
  let(:backup) { test_class.new(model_id: "backup") }
  let(:failing) { test_class.new(model_id: "failing", should_fail: true, fail_count: 10) }

  describe "#with_retry" do
    it "configures retry policy" do
      primary.with_retry(max_attempts: 5, backoff: :linear)

      config = primary.reliability_config
      expect(config[:retry_policy].max_attempts).to eq(5)
      expect(config[:retry_policy].backoff).to eq(:linear)
    end

    it "returns self for chaining" do
      result = primary.with_retry(max_attempts: 3)
      expect(result).to eq(primary)
    end
  end

  describe "#with_fallback" do
    it "adds fallback model" do
      primary.with_fallback(backup)

      config = primary.reliability_config
      expect(config[:fallback_count]).to eq(1)
    end

    it "allows chaining multiple fallbacks" do
      emergency = test_class.new(model_id: "emergency")
      primary.with_fallback(backup).with_fallback(emergency)

      config = primary.reliability_config
      expect(config[:fallback_count]).to eq(2)
    end
  end

  describe "#reliable_generate" do
    context "when primary succeeds" do
      it "returns response from primary" do
        response = primary.reliable_generate([])

        expect(response.content).to include("primary")
      end

      it "does not use fallback" do
        primary.with_fallback(backup)
        primary.reliable_generate([])

        expect(backup.generate_count).to eq(0)
      end
    end

    context "when primary fails and fallback succeeds" do
      it "returns response from fallback" do
        failing.with_fallback(backup)
        response = failing.reliable_generate([])

        expect(response.content).to include("backup")
      end
    end

    context "with retry on failure" do
      let(:sometimes_fails) { test_class.new(model_id: "flaky", should_fail: true, fail_count: 2) }

      it "retries and succeeds" do
        sometimes_fails.with_retry(max_attempts: 5)
        response = sometimes_fails.reliable_generate([])

        expect(response.content).to include("flaky")
        expect(sometimes_fails.generate_count).to eq(3) # 2 failures + 1 success
      end
    end

    context "when all models fail" do
      let(:failing2) { test_class.new(model_id: "failing2", should_fail: true, fail_count: 10) }

      it "raises error" do
        failing.with_fallback(failing2)
        failing.with_retry(max_attempts: 2)

        expect { failing.reliable_generate([]) }.to raise_error(Faraday::TimeoutError)
      end
    end
  end

  describe "event subscriptions" do
    describe "#on_failover" do
      it "subscribes to failover events" do
        events = []
        failing.with_fallback(backup)
        failing.on_failover { |e| events << e }

        failing.reliable_generate([])

        expect(events.size).to eq(1)
        expect(events.first).to be_a(Smolagents::Events::FailoverOccurred)
        expect(events.first.from_model_id).to eq("failing")
        expect(events.first.to_model_id).to eq("backup")
      end
    end

    describe "#on_error" do
      it "subscribes to error events via event queue" do
        event_queue = Smolagents::Events::EventQueue.new
        failing.connect_to(event_queue)
        failing.with_fallback(backup)
        failing.with_retry(max_attempts: 3)

        failing.reliable_generate([])

        # Drain and check error events
        error_events = event_queue.drain.select { |e| e.is_a?(Smolagents::Events::ErrorOccurred) }
        expect(error_events.size).to be >= 1
      end
    end

    describe "#on_recovery" do
      let(:flaky) { test_class.new(model_id: "flaky", should_fail: true, fail_count: 1) }

      it "subscribes to recovery events" do
        recovered = false
        recovery_model_id = nil

        flaky.with_retry(max_attempts: 3)
        flaky.on_recovery do |e|
          recovered = true
          recovery_model_id = e.model_id
        end

        flaky.reliable_generate([])

        expect(recovered).to be true
        expect(recovery_model_id).to eq("flaky")
      end
    end

    describe "#on_retry" do
      let(:sometimes_fails) { test_class.new(model_id: "flaky", should_fail: true, fail_count: 2) }

      it "subscribes to retry events" do
        retry_events = []
        sometimes_fails.with_retry(max_attempts: 5)
        sometimes_fails.on_retry { |e| retry_events << e }

        sometimes_fails.reliable_generate([])

        expect(retry_events.size).to eq(2) # 2 retries before success
        expect(retry_events.first).to be_a(Smolagents::Events::RetryRequested)
      end
    end
  end

  describe "#any_healthy?" do
    let(:health_model) do
      Class.new(test_class) do
        include Smolagents::Concerns::ModelHealth

        def models_request(timeout: 10)
          { "data" => [{ "id" => model_id }] }
        end
      end
    end

    it "returns true if any model in chain is healthy" do
      healthy = health_model.new(model_id: "healthy")
      primary.with_fallback(healthy)

      expect(primary.any_healthy?).to be true
    end
  end

  describe "#reset_reliability" do
    it "clears all reliability configuration" do
      primary.with_retry(max_attempts: 5)
             .with_fallback(backup)
             .reset_reliability

      config = primary.reliability_config
      expect(config[:fallback_count]).to eq(0)
    end
  end

  describe "RetryPolicy" do
    let(:policy) { described_class::RetryPolicy.default }

    it "has sensible defaults" do
      expect(policy.max_attempts).to eq(3)
      expect(policy.base_interval).to eq(1.0)
      expect(policy.backoff).to eq(:exponential)
    end

    it "calculates multiplier based on backoff type" do
      expect(policy.multiplier).to eq(2.0)

      linear = described_class::RetryPolicy.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :linear, retryable_errors: []
      )
      expect(linear.multiplier).to eq(1.5)
    end
  end
end
