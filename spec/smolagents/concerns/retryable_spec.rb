# frozen_string_literal: true

RSpec.describe Smolagents::Concerns::Retryable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Retryable

      attr_accessor :logger
    end
  end

  let(:instance) { test_class.new }

  describe "#with_retry" do
    it "returns result on first successful attempt" do
      result = instance.with_retry do
        "success"
      end

      expect(result).to eq("success")
    end

    it "retries on failure and succeeds" do
      attempts = 0
      result = instance.with_retry(max_attempts: 3) do
        attempts += 1
        raise StandardError, "fail" if attempts < 2

        "success after #{attempts} attempts"
      end

      expect(result).to eq("success after 2 attempts")
      expect(attempts).to eq(2)
    end

    it "raises error after max attempts" do
      attempts = 0
      expect do
        instance.with_retry(max_attempts: 3) do
          attempts += 1
          raise StandardError, "persistent failure"
        end
      end.to raise_error(StandardError, "persistent failure")

      expect(attempts).to eq(3)
    end

    it "only retries specified error classes" do
      expect do
        instance.with_retry(on: [ArgumentError]) do
          raise StandardError, "wrong error type"
        end
      end.to raise_error(StandardError, "wrong error type")
    end

    it "retries multiple error types" do
      attempts = 0
      result = instance.with_retry(on: [ArgumentError, RuntimeError], max_attempts: 3) do
        attempts += 1
        raise ArgumentError if attempts == 1
        raise RuntimeError if attempts == 2

        "success"
      end

      expect(result).to eq("success")
      expect(attempts).to eq(3)
    end

    it "uses exponential backoff" do
      attempts = 0
      delays = []

      allow(instance).to receive(:sleep) do |delay|
        delays << delay
      end

      instance.with_retry(max_attempts: 3, base_delay: 1.0, exponential_base: 2, jitter: false) do
        attempts += 1
        raise StandardError if attempts < 3

        "success"
      end

      expect(delays[0]).to eq(1.0)  # First retry: 1.0 * 2^0
      expect(delays[1]).to eq(2.0)  # Second retry: 1.0 * 2^1
    end

    it "respects max_delay" do
      delays = []
      allow(instance).to receive(:sleep) do |delay|
        delays << delay
      end

      instance.with_retry(
        max_attempts: 5,
        base_delay: 1.0,
        max_delay: 3.0,
        exponential_base: 2,
        jitter: false
      ) do
        raise StandardError if delays.size < 4

        "success"
      end

      expect(delays.all? { |d| d <= 3.0 }).to be true
    end

    it "adds jitter to delays" do
      delays = []
      allow(instance).to receive(:sleep) do |delay|
        delays << delay
      end

      instance.with_retry(max_attempts: 3, base_delay: 1.0, jitter: true) do
        raise StandardError if delays.size < 2

        "success"
      end

      # With jitter, delays should not be exact multiples
      expect(delays).to all(be > 0)
      expect(delays.first).to be_between(1.0, 1.25) # Base 1.0 + up to 25% jitter
    end

    it "logs retry attempts when logger available" do
      logger = instance_double(Logger)
      instance.logger = logger
      attempts = 0

      expect(logger).to receive(:warn).twice.with(%r{Attempt \d+/3 failed.*Retrying})

      instance.with_retry(max_attempts: 3, base_delay: 0.001) do
        attempts += 1
        raise StandardError, "test error" if attempts < 3

        "success"
      end
    end
  end

  describe "#calculate_delay" do
    it "calculates exponential backoff correctly" do
      delay1 = instance.send(:calculate_delay,
                             attempt: 1, base: 1.0, max: 100.0, exponential_base: 2, jitter: false)
      delay2 = instance.send(:calculate_delay,
                             attempt: 2, base: 1.0, max: 100.0, exponential_base: 2, jitter: false)
      delay3 = instance.send(:calculate_delay,
                             attempt: 3, base: 1.0, max: 100.0, exponential_base: 2, jitter: false)

      expect(delay1).to eq(1.0)  # 1.0 * 2^0
      expect(delay2).to eq(2.0)  # 1.0 * 2^1
      expect(delay3).to eq(4.0)  # 1.0 * 2^2
    end

    it "respects maximum delay" do
      delay = instance.send(:calculate_delay,
                            attempt: 10, base: 1.0, max: 10.0, exponential_base: 2, jitter: false)
      expect(delay).to eq(10.0)
    end

    it "adds jitter when enabled" do
      delays = 10.times.map do
        instance.send(:calculate_delay,
                      attempt: 1, base: 1.0, max: 100.0, exponential_base: 2, jitter: true)
      end

      # All delays should be >= base
      expect(delays).to all(be >= 1.0)
      # Delays should vary (jitter)
      expect(delays.uniq.size).to be > 1
      # Should not exceed base + 25%
      expect(delays).to all(be <= 1.25)
    end
  end

  describe "integration example" do
    it "works in a model-like class with retries" do
      api_client = Class.new do
        include Smolagents::Concerns::Retryable

        def call_api(fail_times: 0)
          with_retry(max_attempts: 3, base_delay: 0.001) do
            @call_count ||= 0
            @call_count += 1

            raise StandardError, "Connection failed" if @call_count <= fail_times

            { success: true, attempt: @call_count }
          end
        end
      end

      client = api_client.new
      result = client.call_api(fail_times: 2)

      expect(result[:success]).to be true
      expect(result[:attempt]).to eq(3)
    end
  end
end
