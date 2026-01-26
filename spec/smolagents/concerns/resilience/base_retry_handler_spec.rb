require "spec_helper"

RSpec.describe Smolagents::Concerns::BaseRetryHandler do
  let(:default_policy) { Smolagents::Types::RetryPolicy.default }
  let(:no_delay) { described_class::NOOP_DELAY }

  describe "#initialize" do
    it "uses default policy when not specified" do
      handler = described_class.new
      expect(handler.policy.max_attempts).to eq(3)
    end

    it "uses blocking delay by default" do
      handler = described_class.new
      expect(handler.on_delay).to eq(described_class::BLOCKING_DELAY)
    end

    it "accepts custom policy" do
      policy = Smolagents::Types::RetryPolicy.aggressive
      handler = described_class.new(policy:)
      expect(handler.policy.max_attempts).to eq(5)
    end

    it "accepts custom delay handler" do
      custom_delay = ->(s) { "waited #{s}" }
      handler = described_class.new(on_delay: custom_delay)
      expect(handler.on_delay).to eq(custom_delay)
    end
  end

  describe "#execute" do
    it "returns result on first success" do
      handler = described_class.new(on_delay: no_delay)
      result = handler.execute { "success" }
      expect(result).to eq("success")
    end

    it "retries on retriable error" do
      attempts = 0
      handler = described_class.new(on_delay: no_delay)

      result = handler.execute do
        attempts += 1
        raise Faraday::TimeoutError if attempts < 2

        "success after retry"
      end

      expect(result).to eq("success after retry")
      expect(attempts).to eq(2)
    end

    it "raises after max attempts exhausted" do
      handler = described_class.new(on_delay: no_delay)

      expect do
        handler.execute { raise Faraday::TimeoutError, "always fails" }
      end.to raise_error(Faraday::TimeoutError, "always fails")
    end

    it "raises immediately for non-retriable errors" do
      attempts = 0
      handler = described_class.new(on_delay: no_delay)

      expect do
        handler.execute do
          attempts += 1
          raise ArgumentError, "not retriable"
        end
      end.to raise_error(ArgumentError)

      expect(attempts).to eq(1)
    end

    it "calls on_delay with backoff seconds" do
      delays = []
      handler = described_class.new(
        policy: Smolagents::Types::RetryPolicy.new(
          max_attempts: 3,
          base_interval: 1.0,
          max_interval: 10.0,
          backoff: :constant,
          jitter: 0,
          retryable_errors: [RuntimeError]
        ),
        on_delay: ->(s) { delays << s }
      )

      expect do
        handler.execute { raise "fail" }
      end.to raise_error(RuntimeError)

      expect(delays.size).to eq(2) # 2 retries before exhaustion
      expect(delays).to all(eq(1.0))
    end

    it "calls on_retry callback before each retry" do
      retry_calls = []
      handler = described_class.new(
        on_delay: no_delay,
        on_retry: ->(info) { retry_calls << info }
      )

      expect do
        handler.execute { raise Faraday::TimeoutError, "fail" }
      end.to raise_error(Faraday::TimeoutError)

      expect(retry_calls.size).to eq(2) # 2 retries
      expect(retry_calls.first).to include(attempt: 1, max_attempts: 3)
    end

    it "uses custom error classifier when provided" do
      attempts = 0
      handler = described_class.new(
        on_delay: no_delay,
        error_classifier: ->(e) { e.is_a?(StandardError) }
      )

      result = handler.execute do
        attempts += 1
        raise "custom error" if attempts < 2

        "success"
      end

      expect(result).to eq("success")
      expect(attempts).to eq(2)
    end
  end

  describe "#try_once" do
    it "returns success result on success" do
      handler = described_class.new
      result = handler.try_once { "value" }

      expect(result[:status]).to eq(:success)
      expect(result[:value]).to eq("value")
    end

    it "returns retry_needed for retriable error" do
      handler = described_class.new
      result = handler.try_once(attempt: 1) { raise Faraday::TimeoutError, "timeout" }

      expect(result[:status]).to eq(:retry_needed)
      expect(result[:backoff_seconds]).to be_positive
      expect(result[:attempt]).to eq(1)
      expect(result[:max_attempts]).to eq(3)
      expect(result[:error]).to be_a(Faraday::TimeoutError)
    end

    it "returns exhausted when max attempts reached" do
      handler = described_class.new
      result = handler.try_once(attempt: 3) { raise Faraday::TimeoutError, "timeout" }

      expect(result[:status]).to eq(:exhausted)
      expect(result[:error]).to be_a(Faraday::TimeoutError)
    end

    it "returns error for non-retriable errors" do
      handler = described_class.new
      result = handler.try_once { raise ArgumentError, "not retriable" }

      expect(result[:status]).to eq(:error)
      expect(result[:error]).to be_a(ArgumentError)
    end

    it "uses retry-after header when available" do
      error = Class.new(Faraday::Error) do
        def retry_after = 5.0
      end.new("rate limited")

      handler = described_class.new(
        policy: Smolagents::Types::RetryPolicy.default,
        error_classifier: ->(_) { true } # Force retriable
      )

      result = handler.try_once { raise error }
      expect(result[:backoff_seconds]).to eq(5.0)
    end

    it "caps retry-after at max_interval" do
      error = Class.new(Faraday::Error) do
        def retry_after = 120.0
      end.new("rate limited")

      handler = described_class.new(
        policy: Smolagents::Types::RetryPolicy.new(
          max_attempts: 3,
          base_interval: 1.0,
          max_interval: 30.0,
          backoff: :exponential,
          jitter: 0,
          retryable_errors: [Faraday::Error]
        )
      )

      result = handler.try_once { raise error }
      expect(result[:backoff_seconds]).to eq(30.0)
    end
  end

  describe "BLOCKING_DELAY" do
    it "is defined as a callable" do
      expect(described_class::BLOCKING_DELAY).to respond_to(:call)
    end
  end

  describe "NOOP_DELAY" do
    it "does nothing when called" do
      expect { described_class::NOOP_DELAY.call(1.0) }.not_to raise_error
    end
  end
end
