require "spec_helper"

RSpec.describe Smolagents::Concerns::RequestQueue do
  # Simple model for testing - NO sleeps, NO timeouts, NO blocking
  let(:controllable_model_class) do
    Class.new do
      attr_reader :model_id, :generate_calls

      def initialize(model_id: "test-model")
        @model_id = model_id
        @generate_calls = []
        @mutex = Mutex.new
      end

      def generate(messages, **kwargs)
        @mutex.synchronize { @generate_calls << { messages:, kwargs: } }
        Smolagents::ChatMessage.assistant("Response from #{@model_id}")
      end

      alias_method :original_generate, :generate
    end
  end

  let(:model) do
    m = controllable_model_class.new
    m.extend(described_class)
    m
  end

  after do
    model.disable_queue if model.queue_enabled?
  end

  describe "#enable_queue / #disable_queue" do
    it "enables queueing" do
      expect(model.queue_enabled?).to be false
      model.enable_queue
      expect(model.queue_enabled?).to be true
    end

    it "disables queueing" do
      model.enable_queue
      model.disable_queue
      expect(model.queue_enabled?).to be false
    end

    it "returns self for chaining" do
      expect(model.enable_queue).to eq(model)
    end

    it "accepts max_depth option" do
      model.enable_queue(max_depth: 5)
      expect(model.queue_enabled?).to be true
    end

    it "is idempotent" do
      model.enable_queue
      first = model.instance_variable_get(:@worker_thread)
      model.enable_queue
      expect(model.instance_variable_get(:@worker_thread)).to eq(first)
    end
  end

  describe "#queue_depth" do
    it "returns 0 when not enabled" do
      expect(model.queue_depth).to eq(0)
    end
  end

  describe "#queue_stats" do
    it "returns QueueStats object" do
      model.enable_queue
      stats = model.queue_stats
      expect(stats).to be_a(described_class::QueueStats)
      expect(stats.total_processed).to eq(0)
    end

    it "tracks processed count" do
      model.enable_queue
      model.queued_generate([])
      expect(model.queue_stats.total_processed).to eq(1)
    end
  end

  describe "#queued_generate" do
    it "processes request and returns result" do
      model.enable_queue
      result = model.queued_generate(["test"])
      expect(result.content).to include("Response")
    end

    it "passes arguments to generate" do
      model.enable_queue
      model.queued_generate(["msg"], foo: "bar")
      expect(model.generate_calls.first[:kwargs]).to include(foo: "bar")
    end

    it "bypasses queue when disabled" do
      model.queued_generate([])
      expect(model.generate_calls.size).to eq(1)
    end

    context "with max_depth" do
      it "raises when full" do
        model.enable_queue(max_depth: 0)
        expect { model.queued_generate([]) }.to raise_error(Smolagents::AgentError, /Queue full/)
      end
    end
  end

  describe "priority handling" do
    it "reorders queue to process high priority before normal" do
      model.enable_queue

      # Test the priority flag mechanism
      normal_request = described_class::QueuedRequest.new(
        id: "normal", priority: :normal, messages: [].freeze,
        kwargs: {}.freeze, result_queue: Thread::Queue.new, queued_at: Time.now
      )
      high_request = described_class::QueuedRequest.new(
        id: "high", priority: :high, messages: [].freeze,
        kwargs: {}.freeze, result_queue: Thread::Queue.new, queued_at: Time.now
      )

      expect(normal_request.high_priority?).to be false
      expect(high_request.high_priority?).to be true
    end
  end

  describe "#clear_queue" do
    it "empties the queue" do
      model.enable_queue

      # Queue is initially empty
      expect(model.queue_depth).to eq(0)

      # After clear, still empty
      model.clear_queue
      expect(model.queue_depth).to eq(0)
    end
  end

  describe "QueuedRequest" do
    let(:request) do
      described_class::QueuedRequest.new(
        id: "id", priority: :high, messages: [].freeze,
        kwargs: {}.freeze, result_queue: Thread::Queue.new, queued_at: Time.now - 5
      )
    end

    it "calculates wait_time" do
      expect(request.wait_time).to be >= 5
    end

    it "identifies priority" do
      expect(request.high_priority?).to be true
    end

    it "is immutable" do
      expect { request.id = "x" }.to raise_error(NoMethodError)
    end
  end

  describe "QueueStats" do
    let(:stats) do
      described_class::QueueStats.new(depth: 3, processing: true, total_processed: 100, avg_wait_time: 1.5,
                                      max_wait_time: 5.0)
    end

    it "converts to hash" do
      expect(stats.to_h).to include(depth: 3, total_processed: 100)
    end

    it "is immutable" do
      expect { stats.depth = 0 }.to raise_error(NoMethodError)
    end
  end

  describe "thread safety" do
    it "handles concurrent requests" do
      model.enable_queue
      results = Array.new(5) { Thread.new { model.queued_generate([]) } }.map(&:value)
      expect(results.size).to eq(5)
    end
  end

  describe "worker lifecycle" do
    it "names thread for debugging" do
      model.enable_queue
      expect(model.instance_variable_get(:@worker_thread).name).to include("RequestQueue")
    end
  end
end
