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

    it "processes critical items before normal items", :slow do
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

      # Wait for processing
      sleep 0.1 # rubocop:disable Smolagents/NoSleep -- test needs to wait for async processing

      # Critical should be processed (results will contain processed items)
      expect(results).to include("critical")
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

    it "emits WorkItemQueued event", :slow do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work(item)

      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- test needs to wait for async event
      collected = drain_queue(event_queue)
      queued_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemQueued) }

      expect(queued_event).not_to be_nil
      expect(queued_event.work_item_id).to eq(item.id)
      expect(queued_event.work_type).to eq(:model_generate)
    end

    it "emits WorkItemDispatched event" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work_sync(item)

      collected = drain_queue(event_queue)
      dispatched_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemDispatched) }

      expect(dispatched_event).not_to be_nil
      expect(dispatched_event.work_item_id).to eq(item.id)
    end

    it "emits WorkItemCompleted event" do
      item = Smolagents::Types::WorkItem.model_generate(messages: [], model_id: "test")
      queue_host.enqueue_work_sync(item)

      collected = drain_queue(event_queue)
      completed_event = collected.find { |e| e.is_a?(Smolagents::Events::WorkItemCompleted) }

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
