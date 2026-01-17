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

  let(:executor) { test_class.new }

  describe "#with_tool_retry" do
    it "succeeds on first attempt when no error" do
      executor.succeed_on_attempt = 1

      result = executor.with_tool_retry { executor.flaky_call }

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

      result = executor.with_tool_retry(policy: fast_policy) do
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
        )) { executor.flaky_call }
      end.to raise_error(Smolagents::RateLimitError)

      expect(executor.call_count).to eq(2)
    end

    it "does not retry non-retryable errors" do
      expect do
        executor.with_tool_retry { raise ArgumentError, "bad arg" }
      end.to raise_error(ArgumentError)
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

        result = executor.with_tool_retry(policy:) { executor.flaky_call }

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
end
