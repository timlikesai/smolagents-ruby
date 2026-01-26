require "spec_helper"

RSpec.describe Smolagents::Concerns::ToolRetry do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ToolRetry

      attr_accessor :call_count, :succeed_on_attempt

      def initialize
        @call_count = 0
        @succeed_on_attempt = 2
      end

      def flaky_call
        @call_count += 1
        raise Smolagents::RateLimitError.new(status_code: 429) if @call_count < @succeed_on_attempt

        "success"
      end
    end
  end

  # No-op delay handler for tests (instant retries)
  let(:no_delay) { ->(_) {} }

  let(:executor) { test_class.new }

  describe "#try_tool_call" do
    it "returns success on successful call" do
      result = executor.try_tool_call { "value" }

      expect(result).to be_success
      expect(result.value).to eq("value")
    end

    it "returns retry_needed for retryable error" do
      policy = Smolagents::Concerns::RetryPolicy.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 10.0,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      result = executor.try_tool_call(policy:, attempt: 1) do
        raise Smolagents::RateLimitError.new(status_code: 429)
      end

      expect(result).to be_retry_needed
      expect(result.retry_info.attempt).to eq(1)
      expect(result.retry_info.backoff_seconds).to eq(1.0)
    end

    it "returns exhausted when max attempts reached" do
      policy = Smolagents::Concerns::RetryPolicy.new(
        max_attempts: 2,
        base_interval: 1.0,
        max_interval: 10.0,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      result = executor.try_tool_call(policy:, attempt: 2) do
        raise Smolagents::RateLimitError.new(status_code: 429)
      end

      expect(result).to be_exhausted
      expect(result.error).to be_a(Smolagents::RateLimitError)
    end

    it "returns error for non-retryable errors" do
      result = executor.try_tool_call { raise ArgumentError, "bad arg" }

      expect(result).to be_error
      expect(result.error).to be_a(ArgumentError)
    end
  end

  describe "#with_tool_retry" do
    it "succeeds on first attempt when no error" do
      executor.succeed_on_attempt = 1

      result = executor.with_tool_retry(on_delay: no_delay) { executor.flaky_call }

      expect(result).to eq("success")
      expect(executor.call_count).to eq(1)
    end

    it "retries on RateLimitError and succeeds" do
      executor.succeed_on_attempt = 2
      fast_policy = Smolagents::Concerns::RetryPolicy.new(
        max_attempts: 3,
        base_interval: 0.001,
        max_interval: 0.01,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      result = executor.with_tool_retry(policy: fast_policy, on_delay: no_delay) do
        executor.flaky_call
      end

      expect(result).to eq("success")
      expect(executor.call_count).to eq(2)
    end

    it "raises after max attempts exceeded" do
      executor.succeed_on_attempt = 10 # Will never succeed

      expect do
        executor.with_tool_retry(policy: Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 2,
          base_interval: 0.01,
          max_interval: 0.1,
          backoff: :constant,
          jitter: 0.0,
          retryable_errors: [Smolagents::RateLimitError]
        ), on_delay: no_delay) { executor.flaky_call }
      end.to raise_error(Smolagents::RateLimitError)

      expect(executor.call_count).to eq(2)
    end

    it "does not retry non-retryable errors" do
      expect do
        executor.with_tool_retry(on_delay: no_delay) { raise ArgumentError, "bad arg" }
      end.to raise_error(ArgumentError)
    end

    it "calls delay handler with backoff duration" do
      executor.succeed_on_attempt = 2
      delays_received = []
      delay_tracker = ->(seconds) { delays_received << seconds }

      policy = Smolagents::Concerns::RetryPolicy.new(
        max_attempts: 3,
        base_interval: 1.5,
        max_interval: 10.0,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      executor.with_tool_retry(policy:, on_delay: delay_tracker) { executor.flaky_call }

      expect(delays_received).to eq([1.5])
    end

    context "with custom policy" do
      it "respects custom max_attempts" do
        policy = Smolagents::Concerns::RetryPolicy.new(
          max_attempts: 4,
          base_interval: 0.001,
          max_interval: 0.01,
          backoff: :constant,
          jitter: 0.0,
          retryable_errors: [Smolagents::RateLimitError]
        )
        executor.succeed_on_attempt = 4

        result = executor.with_tool_retry(policy:, on_delay: no_delay) { executor.flaky_call }

        expect(result).to eq("success")
        expect(executor.call_count).to eq(4)
      end
    end
  end

  describe "default policy" do
    it "retries RateLimitError" do
      expect(described_class.default_policy.retryable_errors)
        .to include(Smolagents::RateLimitError)
    end

    it "retries ServiceUnavailableError" do
      expect(described_class.default_policy.retryable_errors)
        .to include(Smolagents::ServiceUnavailableError)
    end

    it "has 3 max attempts" do
      expect(described_class.default_policy.max_attempts).to eq(3)
    end
  end

  describe Smolagents::Types::RetryResult do
    describe ".success" do
      it "creates a success result" do
        result = described_class.success("value")

        expect(result).to be_success
        expect(result.value).to eq("value")
        expect(result.retry_info).to be_nil
        expect(result.error).to be_nil
      end
    end

    describe ".needs_retry" do
      it "creates a retry-needed result" do
        info = Smolagents::Types::RetryInfo.new(
          backoff_seconds: 2.5,
          attempt: 1,
          max_attempts: 3,
          error: StandardError.new("test")
        )

        result = described_class.needs_retry(info)

        expect(result).to be_retry_needed
        expect(result.retry_info).to eq(info)
      end
    end

    describe ".exhausted" do
      it "creates an exhausted result" do
        error = RuntimeError.new("all retries failed")
        result = described_class.exhausted(error)

        expect(result).to be_exhausted
        expect(result.error).to eq(error)
      end
    end

    describe ".error" do
      it "creates an error result" do
        error = ArgumentError.new("invalid input")
        result = described_class.error(error)

        expect(result).to be_error
        expect(result.error).to eq(error)
      end
    end
  end

  describe Smolagents::Types::RetryInfo do
    it "tracks retry metadata" do
      info = described_class.new(
        backoff_seconds: 5.0,
        attempt: 2,
        max_attempts: 5,
        error: RuntimeError.new("test")
      )

      expect(info.backoff_seconds).to eq(5.0)
      expect(info.attempt).to eq(2)
      expect(info.max_attempts).to eq(5)
      expect(info).to be_retries_remaining
    end

    it "knows when retries are exhausted" do
      info = described_class.new(
        backoff_seconds: 5.0,
        attempt: 5,
        max_attempts: 5,
        error: RuntimeError.new("test")
      )

      expect(info).not_to be_retries_remaining
    end
  end
end
