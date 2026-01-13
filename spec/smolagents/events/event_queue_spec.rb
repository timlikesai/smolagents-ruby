require "spec_helper"

RSpec.describe Smolagents::Events::EventQueue do
  let(:queue) { described_class.new(max_depth: 100) }

  def create_immediate_event
    Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})
  end

  def create_scheduled_event(delay:)
    Smolagents::Events::ToolCallRequested.create(
      tool_name: "test",
      args: {},
      due_at: Time.now + delay
    )
  end

  describe "#push" do
    it "adds events to queue" do
      event = create_immediate_event
      queue.push(event)

      expect(queue.size).to eq(1)
    end

    it "supports << alias" do
      event = create_immediate_event
      queue << event

      expect(queue.size).to eq(1)
    end

    it "returns self for chaining" do
      result = queue.push(create_immediate_event)

      expect(result).to eq(queue)
    end

    it "raises QueueFullError when at max depth" do
      100.times { queue.push(create_immediate_event) }

      expect { queue.push(create_immediate_event) }
        .to raise_error(Smolagents::Events::EventQueue::QueueFullError, /max: 100/)
    end
  end

  describe "#pop_ready" do
    it "returns nil when queue is empty" do
      expect(queue.pop_ready).to be_nil
    end

    it "returns ready events" do
      event = create_immediate_event
      queue.push(event)

      expect(queue.pop_ready).to eq(event)
    end

    it "removes event from queue" do
      queue.push(create_immediate_event)
      queue.pop_ready

      expect(queue.size).to eq(0)
    end

    it "skips scheduled events not yet due" do
      future_event = create_scheduled_event(delay: 60)
      queue.push(future_event)

      expect(queue.pop_ready).to be_nil
    end

    it "returns scheduled events when due" do
      # Event due in the past (already ready)
      past_event = Smolagents::Events::ToolCallRequested.new(
        id: "test",
        tool_name: "test",
        args: {},
        created_at: Time.now - 10,
        due_at: Time.now - 5
      )
      queue.push(past_event)

      expect(queue.pop_ready).to eq(past_event)
    end
  end

  describe "#drain" do
    it "returns empty array when no ready events" do
      expect(queue.drain(max: 10)).to eq([])
    end

    it "returns up to max ready events" do
      5.times { queue.push(create_immediate_event) }

      events = queue.drain(max: 3)

      expect(events.size).to eq(3)
      expect(queue.size).to eq(2)
    end

    it "stops when no more ready events" do
      2.times { queue.push(create_immediate_event) }
      queue.push(create_scheduled_event(delay: 60)) # Not ready

      events = queue.drain(max: 10)

      expect(events.size).to eq(2)
    end
  end

  describe "priority ordering" do
    it "returns error events before immediate events" do
      immediate = create_immediate_event
      error = Smolagents::Events::ErrorOccurred.create(
        error: StandardError.new("test"),
        context: {}
      )

      queue.push(immediate, priority: :immediate)
      queue.push(error, priority: :error)

      first = queue.pop_ready
      expect(first).to eq(error)
    end

    it "returns immediate events before scheduled events" do
      scheduled = Smolagents::Events::ToolCallRequested.new(
        id: "scheduled",
        tool_name: "test",
        args: {},
        created_at: Time.now - 10,
        due_at: Time.now - 5 # Due but low priority
      )
      immediate = create_immediate_event

      queue.push(scheduled, priority: :scheduled)
      queue.push(immediate, priority: :immediate)

      first = queue.pop_ready
      expect(first).to eq(immediate)
    end
  end

  describe "#cleanup_stale" do
    it "removes events past due by threshold" do
      stale = Smolagents::Events::ToolCallRequested.new(
        id: "stale",
        tool_name: "test",
        args: {},
        created_at: Time.now - 120,
        due_at: Time.now - 90 # 90 seconds past due
      )
      fresh = create_immediate_event

      queue.push(stale)
      queue.push(fresh)

      removed = queue.cleanup_stale(threshold: 60)

      expect(removed).to eq([stale])
      expect(queue.size).to eq(1)
    end

    it "returns empty array when no stale events" do
      queue.push(create_immediate_event)

      removed = queue.cleanup_stale(threshold: 60)

      expect(removed).to eq([])
    end
  end

  describe "#ready?" do
    it "returns false when queue is empty" do
      expect(queue.ready?).to be false
    end

    it "returns true when immediate events exist" do
      queue.push(create_immediate_event)

      expect(queue.ready?).to be true
    end

    it "returns false when only scheduled events exist" do
      queue.push(create_scheduled_event(delay: 60))

      expect(queue.ready?).to be false
    end
  end

  describe "#next_due_in" do
    it "returns nil when no scheduled events" do
      queue.push(create_immediate_event)

      expect(queue.next_due_in).to be_nil
    end

    it "returns time until next scheduled event" do
      queue.push(create_scheduled_event(delay: 30))

      expect(queue.next_due_in).to be_within(1).of(30)
    end

    it "returns 0 for past-due events" do
      past_event = Smolagents::Events::ToolCallRequested.new(
        id: "past",
        tool_name: "test",
        args: {},
        created_at: Time.now - 10,
        due_at: Time.now - 5
      )
      queue.push(past_event)

      expect(queue.next_due_in).to eq(0.0)
    end
  end

  describe "#stats" do
    it "returns queue statistics" do
      queue.push(create_immediate_event, priority: :immediate)
      queue.push(create_immediate_event, priority: :error)
      queue.push(create_scheduled_event(delay: 60), priority: :scheduled)

      stats = queue.stats

      expect(stats[:size]).to eq(3)
      expect(stats[:max_depth]).to eq(100)
      expect(stats[:ready_count]).to eq(2)
      expect(stats[:scheduled_count]).to eq(1)
    end
  end

  describe "thread safety" do
    it "handles concurrent pushes" do
      threads = Array.new(10) do
        Thread.new { 10.times { queue.push(create_immediate_event) } }
      end
      threads.each(&:join)

      expect(queue.size).to eq(100)
    end

    it "handles concurrent pop_ready" do
      100.times { queue.push(create_immediate_event) }

      results = []
      mutex = Mutex.new
      threads = Array.new(10) do
        Thread.new do
          10.times do
            event = queue.pop_ready
            mutex.synchronize { results << event } if event
          end
        end
      end
      threads.each(&:join)

      expect(results.size).to eq(100)
      expect(queue.size).to eq(0)
    end
  end
end
