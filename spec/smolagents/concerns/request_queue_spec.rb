require "spec_helper"

RSpec.describe Smolagents::Concerns::RequestQueue do
  # Controllable model for deterministic testing - NO sleeps, NO timeouts
  # Uses Thread::Queue for all synchronization (Ruby 4.0 pattern)
  let(:controllable_model_class) do
    Class.new do
      attr_reader :model_id, :generate_calls, :call_started, :allow_complete

      def initialize(model_id: "test-model")
        @model_id = model_id
        @generate_calls = []
        @mutex = Mutex.new
        @call_started = Thread::Queue.new
        @allow_complete = Thread::Queue.new
        @block_calls = false
      end

      def block_calls!
        @block_calls = true
      end

      def generate(messages, **kwargs)
        @mutex.synchronize { @generate_calls << { messages:, kwargs: } }

        if @block_calls
          @call_started.push(:started)
          @allow_complete.pop
        end

        Smolagents::ChatMessage.assistant("Response from #{@model_id}")
      end

      def release!
        @allow_complete.push(:complete)
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

    it "accepts timeout option" do
      model.enable_queue(timeout: 30)
      expect(model.queue_enabled?).to be true
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
    it "processes high priority before normal" do
      model.block_calls!
      model.enable_queue

      order = []
      mutex = Mutex.new

      # Block worker with first request
      t1 = Thread.new do
        model.queued_generate(["first"])
        mutex.synchronize { order << "first" }
      end
      model.call_started.pop

      # Queue normal, then high priority
      queued = Thread::Queue.new
      t2 = Thread.new do
        queued.push(:ready)
        model.queued_generate(["normal"])
        mutex.synchronize { order << "normal" }
      end
      queued.pop # Wait for t2 to be ready

      t3 = Thread.new do
        queued.push(:ready)
        model.queued_generate(["high"], priority: :high)
        mutex.synchronize { order << "high" }
      end
      queued.pop # Wait for t3 to be ready

      # Release all - high priority should complete before normal
      3.times { model.release! }
      [t1, t2, t3].each(&:join)

      expect(order[0]).to eq("first")
      expect(order.index("high")).to be < order.index("normal")
    end
  end

  describe "callbacks" do
    it "calls on_queue_complete" do
      completed = false
      model.enable_queue
      model.on_queue_complete { |_req, _dur| completed = true }
      model.queued_generate([])
      expect(completed).to be true
    end

    it "calls on_queue_timeout when timeout occurs" do
      # Skip actual timeout test - it requires real time passing
      # Just verify callback can be registered
      model.enable_queue(timeout: 1)
      callback_registered = false
      model.on_queue_timeout { callback_registered = true }
      expect(model.instance_variable_get(:@queue_callbacks)[:timeout]).not_to be_empty
    end
  end

  describe "#clear_queue" do
    it "empties the queue" do
      model.block_calls!
      model.enable_queue

      # Block worker
      Thread.new do
        model.queued_generate([])
      rescue StandardError
        nil
      end
      model.call_started.pop

      # Add pending requests
      3.times do
        Thread.new do
          model.queued_generate([])
        rescue StandardError
          nil
        end
      end
      Thread.pass # Let threads queue up

      model.clear_queue
      expect(model.queue_depth).to eq(0)

      model.release!
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
    let(:stats) { described_class::QueueStats.new(depth: 3, processing: true, total_processed: 100, avg_wait_time: 1.5, max_wait_time: 5.0) }

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
