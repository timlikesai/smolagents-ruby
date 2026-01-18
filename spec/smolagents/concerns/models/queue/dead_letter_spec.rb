require "spec_helper"

RSpec.describe Smolagents::Concerns::RequestQueue::DeadLetter do
  subject(:model) { test_class.new }

  let(:test_class) do
    Class.new do
      extend Smolagents::Concerns::RequestQueue::DeadLetter
      extend Smolagents::Events::Emitter

      def self.model_id_for_events
        "test-model"
      end

      def self.generate_without_queue(messages, **_kwargs)
        "result for #{messages}"
      end
    end
  end

  let(:mock_request) do
    Smolagents::Concerns::RequestQueue::QueuedRequest.new(
      id: "req-123",
      priority: :normal,
      messages: [{ role: "user", content: "test" }],
      kwargs: {},
      result_queue: Thread::Queue.new,
      queued_at: Time.now
    )
  end

  describe "#enable_dlq" do
    it "enables the DLQ with default max size" do
      test_class.enable_dlq
      expect(test_class.dlq_enabled?).to be true
      expect(test_class.dlq_size).to eq(0)
    end

    it "accepts custom max size" do
      test_class.enable_dlq(max_size: 50)
      expect(test_class.dlq_enabled?).to be true
    end
  end

  describe "#disable_dlq" do
    before { test_class.enable_dlq }

    it "disables the DLQ" do
      test_class.disable_dlq
      expect(test_class.dlq_enabled?).to be false
    end
  end

  describe "failed request handling" do
    before { test_class.enable_dlq(max_size: 5) }

    it "adds failed requests to the DLQ" do
      error = RuntimeError.new("test error")
      test_class.send(:add_to_dlq, mock_request, error)

      expect(test_class.dlq_size).to eq(1)
      failed = test_class.failed_requests.first
      expect(failed.error).to eq("RuntimeError")
      expect(failed.error_message).to eq("test error")
      expect(failed.attempts).to eq(1)
    end

    it "evicts oldest requests when at capacity (FIFO)" do
      6.times do |i|
        request = Smolagents::Concerns::RequestQueue::QueuedRequest.new(
          id: "req-#{i}",
          priority: :normal,
          messages: [{ role: "user", content: "test #{i}" }],
          kwargs: {},
          result_queue: Thread::Queue.new,
          queued_at: Time.now
        )
        test_class.send(:add_to_dlq, request, RuntimeError.new("error #{i}"))
      end

      expect(test_class.dlq_size).to eq(5)
      # First request should have been evicted
      expect(test_class.failed_requests.first.error_message).to eq("error 1")
    end
  end

  describe "#retry_failed" do
    before do
      test_class.enable_dlq
      test_class.send(:add_to_dlq, mock_request, RuntimeError.new("original error"))
    end

    it "retries failed requests" do
      results = test_class.retry_failed(1)

      expect(results.first).to include("result for")
      expect(test_class.dlq_size).to eq(0)
    end

    it "does nothing when count is zero" do
      results = test_class.retry_failed(0)

      expect(results).to be_empty
      expect(test_class.dlq_size).to eq(1)
    end

    it "re-adds to DLQ if retry fails" do
      allow(test_class).to receive(:generate_without_queue).and_raise(RuntimeError.new("retry error"))

      results = test_class.retry_failed(1)

      expect(results.first).to be_a(RuntimeError)
      expect(test_class.dlq_size).to eq(1)
      expect(test_class.failed_requests.first.attempts).to eq(2)
    end
  end

  describe "#clear_dlq" do
    before do
      test_class.enable_dlq
      test_class.send(:add_to_dlq, mock_request, RuntimeError.new("error"))
    end

    it "clears all failed requests" do
      expect(test_class.dlq_size).to eq(1)
      test_class.clear_dlq
      expect(test_class.dlq_size).to eq(0)
    end
  end
end

RSpec.describe Smolagents::Concerns::RequestQueue::FailedRequest do
  subject(:failed) do
    described_class.new(
      request: mock_request,
      error: "RuntimeError",
      error_message: "something went wrong",
      attempts: 2,
      failed_at: frozen_time
    )
  end

  let(:frozen_time) { Time.new(2026, 1, 18, 12, 0, 0) }

  let(:mock_request) do
    Smolagents::Concerns::RequestQueue::QueuedRequest.new(
      id: "req-abc",
      priority: :high,
      messages: [{ role: "user", content: "test" }],
      kwargs: { temperature: 0.7 },
      result_queue: Thread::Queue.new,
      queued_at: Time.now
    )
  end

  describe "#to_h" do
    it "serializes to a hash" do
      result = failed.to_h

      expect(result[:request_id]).to eq("req-abc")
      expect(result[:error]).to eq("RuntimeError")
      expect(result[:error_message]).to eq("something went wrong")
      expect(result[:attempts]).to eq(2)
      expect(result[:failed_at]).to start_with("2026-01-18T12:00:00")
    end
  end

  describe "#age" do
    it "calculates time since failure" do
      allow(Time).to receive(:now).and_return(frozen_time + 60)
      expect(failed.age).to be_within(1).of(60)
    end
  end
end
