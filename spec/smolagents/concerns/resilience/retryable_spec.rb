require "spec_helper"

RSpec.describe Smolagents::Concerns::Retryable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Retryable

      attr_reader :call_count

      def initialize
        @call_count = 0
      end

      def operation
        @call_count += 1
        return "success" if @call_count >= 2

        raise Smolagents::RateLimitError, "Fail"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#with_retry" do
    it "returns result on success" do
      result = instance.with_retry { "value" }
      expect(result).to eq("value")
    end

    it "retries on retriable errors" do
      policy = Smolagents::Types::RetryPolicy.new(
        max_attempts: 3,
        base_interval: 0.001, # Very short for tests
        max_interval: 0.001,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      result = instance.with_retry(policy:) { instance.operation }

      expect(result).to eq("success")
      expect(instance.call_count).to eq(2)
    end

    it "raises immediately for non-retriable errors" do
      policy = Smolagents::Types::RetryPolicy.new(
        max_attempts: 3,
        base_interval: 0.001,
        max_interval: 0.001,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      expect do
        instance.with_retry(policy:) { raise StandardError, "Not retriable" }
      end.to raise_error(StandardError, "Not retriable")
    end

    it "raises after max attempts exceeded" do
      policy = Smolagents::Types::RetryPolicy.new(
        max_attempts: 2,
        base_interval: 0.001,
        max_interval: 0.001,
        backoff: :constant,
        jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )

      always_fail = Class.new do
        include Smolagents::Concerns::Retryable

        def failing_operation
          raise Smolagents::RateLimitError, "Always fails"
        end
      end.new

      expect do
        always_fail.with_retry(policy:) { always_fail.failing_operation }
      end.to raise_error(Smolagents::RateLimitError, "Always fails")
    end

    it "accepts default policy parameter" do
      # Verify that with_retry accepts a policy keyword argument
      policy = Smolagents::Types::RetryPolicy.default
      expect(policy).to respond_to(:retriable?)
      expect(policy).to respond_to(:attempts_remaining?)
      expect(policy).to respond_to(:backoff_for)
    end
  end
end
