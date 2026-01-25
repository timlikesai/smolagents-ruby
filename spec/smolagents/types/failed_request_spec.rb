require "smolagents"

RSpec.describe Smolagents::Types::FailedRequest do
  let(:result_queue) { Thread::Queue.new }
  let(:original_request) do
    Smolagents::Types::QueuedRequest.new(
      id: "req-123",
      priority: :normal,
      messages: [{ role: "user", content: "Hello" }],
      kwargs: {},
      result_queue:,
      queued_at: Time.now - 10
    )
  end

  describe ".new" do
    it "creates a failed request record" do
      failed = described_class.new(
        request: original_request,
        error: "Faraday::TimeoutError",
        error_message: "execution expired",
        attempts: 3,
        failed_at: Time.now
      )

      expect(failed.request).to eq(original_request)
      expect(failed.error).to eq("Faraday::TimeoutError")
      expect(failed.error_message).to eq("execution expired")
      expect(failed.attempts).to eq(3)
    end

    it "is immutable" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now
      )
      expect(failed).to be_frozen
    end
  end

  describe ".from_error" do
    it "creates from StandardError" do
      error = Faraday::TimeoutError.new("execution expired")

      failed = described_class.from_error(
        request: original_request,
        error:,
        attempts: 2
      )

      expect(failed.request).to eq(original_request)
      expect(failed.error).to eq("Faraday::TimeoutError")
      expect(failed.error_message).to eq("execution expired")
      expect(failed.attempts).to eq(2)
    end

    it "defaults attempts to 1" do
      error = RuntimeError.new("test")
      failed = described_class.from_error(request: original_request, error:)
      expect(failed.attempts).to eq(1)
    end

    it "sets failed_at to current time" do
      error = RuntimeError.new("test")
      before = Time.now
      failed = described_class.from_error(request: original_request, error:)
      after = Time.now

      expect(failed.failed_at).to be_between(before, after)
    end
  end

  describe "#age" do
    it "calculates time since failure" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now - 120
      )

      expect(failed.age).to be >= 120
      expect(failed.age).to be < 121
    end
  end

  describe "#recent?" do
    it "returns true for recent failures" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now - 30
      )

      expect(failed.recent?).to be true
      expect(failed.recent?(threshold: 60)).to be true
    end

    it "returns false for old failures" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now - 120
      )

      expect(failed.recent?).to be false
      expect(failed.recent?(threshold: 60)).to be false
    end

    it "accepts custom threshold" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now - 30
      )

      expect(failed.recent?(threshold: 20)).to be false
      expect(failed.recent?(threshold: 60)).to be true
    end
  end

  describe "#retried?" do
    it "returns true when attempts > 1" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 3,
        failed_at: Time.now
      )

      expect(failed.retried?).to be true
    end

    it "returns false when attempts is 1" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 1,
        failed_at: Time.now
      )

      expect(failed.retried?).to be false
    end
  end

  describe "#to_h" do
    it "returns serializable hash" do
      time = Time.now
      failed = described_class.new(
        request: original_request,
        error: "Faraday::TimeoutError",
        error_message: "execution expired",
        attempts: 3,
        failed_at: time
      )

      hash = failed.to_h

      expect(hash[:request_id]).to eq("req-123")
      expect(hash[:error]).to eq("Faraday::TimeoutError")
      expect(hash[:error_message]).to eq("execution expired")
      expect(hash[:attempts]).to eq(3)
      expect(hash[:failed_at]).to eq(time.iso8601)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      failed = described_class.new(
        request: original_request,
        error: "Error",
        error_message: "msg",
        attempts: 2,
        failed_at: Time.now
      )

      case failed
      in { error:, attempts: }
        expect(error).to eq("Error")
        expect(attempts).to eq(2)
      else
        raise "Pattern should match"
      end
    end
  end
end
