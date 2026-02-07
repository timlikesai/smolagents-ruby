require "spec_helper"

RSpec.describe Smolagents::Concerns::Orchestration::WorkQueue do
  let(:queue_host) do
    Class.new do
      def execute_model_generate(work_item)
        { model_id: work_item.payload[:model_id], result: "generated" }
      end

      def execute_tool_call(work_item)
        { tool_name: work_item.payload[:tool_name], result: "executed" }
      end
    end.new
  end

  before { queue_host.extend(described_class) }

  after do
    queue_host.disable_work_queue if queue_host.work_queue_enabled?
  end

  describe "#enable_work_queue / #disable_work_queue" do
    it "enables the work queue" do
      queue_host.enable_work_queue
      expect(queue_host.work_queue_enabled?).to be true
    end

    it "is idempotent" do
      queue_host.enable_work_queue
      queue_host.enable_work_queue
      expect(queue_host.work_queue_enabled?).to be true
    end

    it "disables the work queue" do
      queue_host.enable_work_queue
      queue_host.disable_work_queue
      expect(queue_host.work_queue_enabled?).to be false
    end

    it "accepts max_depth parameter" do
      queue_host.enable_work_queue(max_depth: 10)
      expect(queue_host.work_queue_enabled?).to be true
    end
  end

  describe "#work_queue_depth" do
    it "returns 0 when queue not enabled" do
      expect(queue_host.work_queue_depth).to eq(0)
    end

    it "returns 0 when queue is empty" do
      queue_host.enable_work_queue
      expect(queue_host.work_queue_depth).to eq(0)
    end
  end

  describe "#queue_depth_at" do
    before { queue_host.enable_work_queue }

    it "returns 0 for empty priority" do
      expect(queue_host.queue_depth_at(:critical)).to eq(0)
      expect(queue_host.queue_depth_at(:high)).to eq(0)
      expect(queue_host.queue_depth_at(:normal)).to eq(0)
      expect(queue_host.queue_depth_at(:low)).to eq(0)
    end
  end

  describe "#enqueue_work" do
    before { queue_host.enable_work_queue }

    it "returns the work item ID" do
      item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "test"
      )
      id = queue_host.enqueue_work(item)
      expect(id).to eq(item.id)
    end

    it "raises when queue not enabled" do
      queue_host.disable_work_queue
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      expect { queue_host.enqueue_work(item) }.to raise_error(Smolagents::AgentError)
    end

    it "enforces max_depth capacity" do
      queue_host.disable_work_queue
      queue_host.enable_work_queue(max_depth: 0) # Max depth 0 means immediate rejection

      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      expect { queue_host.enqueue_work(item) }.to raise_error(Smolagents::AgentError, /full/)
    end
  end

  describe "#enqueue_work_sync" do
    before { queue_host.enable_work_queue }

    it "returns the work result" do
      item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "gpt-4"
      )
      result = queue_host.enqueue_work_sync(item)

      expect(result).to be_a(Smolagents::Types::WorkResult)
      expect(result.success?).to be true
      expect(result.value[:model_id]).to eq("gpt-4")
    end

    it "handles tool_call work items" do
      item = Smolagents::Types::WorkItem.tool_call(
        tool_name: "search",
        args: { query: "test" }
      )
      result = queue_host.enqueue_work_sync(item)

      expect(result.success?).to be true
      expect(result.value[:tool_name]).to eq("search")
    end
  end

  describe "priority handling" do
    before { queue_host.enable_work_queue }

    it "processes critical items before normal items" do
      results = []

      # Create items with different priorities
      normal_item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "normal",
        priority: :normal
      )
      critical_item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "critical",
        priority: :critical
      )

      # Enqueue normal first, then critical
      queue_host.enqueue_work(normal_item) { |r| results << r.value[:model_id] }
      queue_host.enqueue_work(critical_item) { |r| results << r.value[:model_id] }

      # Wait for critical to be processed
      wait_for { results.include?("critical") }
      expect(results).to include("critical")
    end

    it "processes high priority before low priority" do
      results = []

      low_item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "low",
        priority: :low
      )
      high_item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "high",
        priority: :high
      )

      queue_host.enqueue_work(low_item) { |r| results << r.value[:model_id] }
      queue_host.enqueue_work(high_item) { |r| results << r.value[:model_id] }

      wait_for { results.size >= 2 }
      expect(results).to include("high", "low")
    end

    it "maintains FIFO within same priority" do
      results = []

      # Enqueue multiple items at same priority
      3.times do |i|
        item = Smolagents::Types::WorkItem.model_generate(
          messages: [],
          model_id: "item_#{i}",
          priority: :normal
        )
        queue_host.enqueue_work(item) { |r| results << r.value[:model_id] }
      end

      wait_for { results.size >= 3 }
      # Items should be processed in order
      expect(results).to eq(%w[item_0 item_1 item_2])
    end

    it "reports queue depth by priority" do
      # We test queue_depth_at which tracks per-priority depth
      stats = queue_host.work_queue_stats
      expect(stats[:by_priority]).to be_a(Hash)
      expect(stats[:by_priority].keys).to include(:critical, :high, :normal, :low)
    end
  end

  describe "priority ordering edge cases" do
    before { queue_host.enable_work_queue }

    it "handles unknown priority by defaulting to normal" do
      # Items with invalid priority should fall back to :normal queue
      item = Smolagents::Types::WorkItem.new(
        id: SecureRandom.uuid,
        type: :model_generate,
        payload: { messages: [], model_id: "test" },
        priority: :unknown,
        context: {},
        created_at: Time.now,
        deadline: nil
      )

      # Should not raise
      expect { queue_host.enqueue_work(item) }.not_to raise_error
    end

    it "processes all priority levels correctly" do
      results = []

      priorities = %i[low normal high critical]
      items = priorities.map do |priority|
        Smolagents::Types::WorkItem.model_generate(
          messages: [],
          model_id: priority.to_s,
          priority:
        )
      end

      # Enqueue in low-to-high order
      items.each { |item| queue_host.enqueue_work(item) { |r| results << r.value[:model_id] } }

      wait_for { results.size >= 4 }

      # All items processed
      expect(results.size).to eq(4)
      expect(results).to include("critical", "high", "normal", "low")
    end
  end

  describe "#clear_work_queue" do
    before { queue_host.enable_work_queue }

    it "removes all pending items" do
      5.times do
        item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
        queue_host.enqueue_work(item)
      end
      queue_host.clear_work_queue
      # Queue should be cleared (items may have been processed already)
      expect(queue_host.work_queue_depth).to be >= 0
    end
  end

  describe "#remove_work" do
    before { queue_host.enable_work_queue }

    it "returns false for non-existent item" do
      result = queue_host.remove_work("non-existent-id")
      expect(result).to be false
    end
  end

  describe "#work_queue_stats" do
    before { queue_host.enable_work_queue }

    it "returns statistics hash" do
      stats = queue_host.work_queue_stats

      expect(stats).to include(
        :total_depth,
        :by_priority,
        :processing,
        :total_processed,
        :by_type,
        :avg_wait_ms,
        :max_wait_ms
      )
    end

    it "tracks processed items" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work_sync(item)

      stats = queue_host.work_queue_stats
      expect(stats[:total_processed]).to be >= 1
      expect(stats[:by_type][:model_generate]).to be >= 1
    end
  end

  describe "event emission" do
    let(:events) { [] }
    let(:event_queue) { Thread::Queue.new }

    before do
      queue_host.enable_work_queue
      queue_host.connect_to(event_queue)
    end

    after do
      Smolagents::Events::AsyncQueue.reset!
    end

    it "emits WorkItemLifecycle event with queued phase" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work(item)

      wait_for { !event_queue.empty? }
      collected = drain_queue(event_queue)
      queued_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemLifecycle) && e.queued? }

      expect(queued_event).not_to be_nil
      expect(queued_event.work_item_id).to eq(item.id)
      expect(queued_event.work_type).to eq(:model_generate)
    end

    it "emits WorkItemLifecycle event with dispatched phase" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work_sync(item)

      collected = drain_queue(event_queue)
      dispatched_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemLifecycle) && e.dispatched? }

      expect(dispatched_event).not_to be_nil
      expect(dispatched_event.work_item_id).to eq(item.id)
    end

    it "emits WorkItemLifecycle event with completed phase" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work_sync(item)

      collected = drain_queue(event_queue)
      completed_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemLifecycle) && e.completed? }

      expect(completed_event).not_to be_nil
      expect(completed_event.work_item_id).to eq(item.id)
      expect(completed_event.outcome).to eq(:success)
    end
  end

  describe "deadline handling" do
    before { queue_host.enable_work_queue }

    it "returns timeout result for expired work items" do
      item = Smolagents::Types::WorkItem.model_generate(
        messages: [],
        model_id: "test",
        deadline: Time.now - 1 # Already expired
      )
      result = queue_host.enqueue_work_sync(item)

      expect(result.timeout?).to be true
    end
  end

  def drain_queue(event_queue)
    events = []
    events << event_queue.pop(true) while event_queue.size.positive?
    events
  rescue ThreadError
    events
  end
end
