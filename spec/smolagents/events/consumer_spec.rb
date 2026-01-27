require "spec_helper"

# Consumer is now an alias for Eventful - tests verify Eventful's Consumer-compatible API
RSpec.describe Smolagents::Events::Consumer do
  let(:consumer_class) do
    Class.new do
      include Smolagents::Events::Consumer
    end
  end

  let(:consumer) { consumer_class.new }

  after do
    Smolagents::Events::AsyncQueue.reset!
  end

  describe "#on" do
    it "registers handler for event class" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| nil }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ToolCallCompleted)
    end

    it "registers handler for convenience name" do
      consumer.on(:tool_complete) { |_e| nil }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ToolCallCompleted)
    end

    it "returns self for chaining" do
      result = consumer.on(Smolagents::Events::ToolCallCompleted) { nil }
      expect(result).to eq(consumer)
    end
  end

  describe "#consume" do
    it "dispatches to matching handlers" do
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| results << e.tool_name }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(results).to eq(["search"])
    end

    it "does not dispatch to non-matching handlers" do
      results = []
      consumer.on(Smolagents::Events::ErrorOccurred) { |e| results << e }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(results).to be_empty
    end

    it "calls multiple handlers for same event type" do
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| results << 1 }
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| results << 2 }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(results).to eq([1, 2])
    end

    it "returns handler results" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| e.tool_name.upcase }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      results = consumer.consume(event)

      expect(results).to eq(["SEARCH"])
    end

    it "handles errors gracefully and continues processing" do
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| results << "second" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      # Second handler should still run despite first failing
      expect(results).to eq(["second"])
    end

    it "tracks failed handlers" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(consumer.handlers_failed?).to be true
      expect(consumer.failed_handlers.size).to eq(1)
    end

    it "records failure details" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise ArgumentError, "test error" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      failure = consumer.failed_handlers.first
      expect(failure.error_class).to eq("ArgumentError")
      expect(failure.error_message).to eq("test error")
      expect(failure.event_class).to eq("Smolagents::Events::ToolCallCompleted")
      expect(failure.timestamp).to be_a(Time)
    end

    it "returns nil for failed handlers in results array" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| "success" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      results = consumer.consume(event)

      expect(results).to eq([nil, "success"])
    end

    it "returns empty array when no handlers registered" do
      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      results = consumer.consume(event)

      expect(results).to eq([])
    end
  end

  describe "#drain_events" do
    it "drains events from queue and consumes each" do
      queue = Thread::Queue.new
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| results << e.tool_name }

      3.times do |i|
        event = Smolagents::Events::ToolCallCompleted.create(
          request_id: "req-#{i}",
          tool_name: "tool_#{i}",
          result: "ok",
          observation: "done"
        )
        queue.push(event)
      end

      events = consumer.drain_events(queue)

      expect(results).to eq(%w[tool_0 tool_1 tool_2])
      expect(events.size).to eq(3)
      expect(queue.size).to eq(0)
    end

    it "accepts timeout parameter" do
      queue = Thread::Queue.new
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| results << e.tool_name }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "test",
        result: "ok",
        observation: "done"
      )
      queue.push(event)

      events = consumer.drain_events(queue, timeout: 1)

      expect(events.size).to eq(1)
      expect(results).to eq(["test"])
    end

    it "returns early on timeout" do
      queue = Thread::Queue.new

      start = Time.now
      events = consumer.drain_events(queue, timeout: 0.01)
      elapsed = Time.now - start

      expect(events).to be_empty
      expect(elapsed).to be < 0.5
    end
  end

  describe "#clear_handlers" do
    it "removes all handlers" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { nil }
      consumer.on(Smolagents::Events::ErrorOccurred) { nil }

      consumer.clear_handlers

      expect(consumer.event_handlers).to be_empty
    end

    it "returns self for chaining" do
      result = consumer.clear_handlers
      expect(result).to eq(consumer)
    end
  end

  describe "#handlers_failed?" do
    it "returns false when no failures" do
      expect(consumer.handlers_failed?).to be false
    end

    it "returns true after a handler fails" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(consumer.handlers_failed?).to be true
    end
  end

  describe "#clear_failed_handlers" do
    it "clears the failed handlers list" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)
      expect(consumer.handlers_failed?).to be true

      consumer.clear_failed_handlers

      expect(consumer.handlers_failed?).to be false
      expect(consumer.failed_handlers).to be_empty
    end

    it "returns self for chaining" do
      result = consumer.clear_failed_handlers
      expect(result).to eq(consumer)
    end
  end

  describe "error event emission" do
    let(:emitter_consumer_class) do
      Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Events::Consumer

        attr_reader :emitted_events

        def initialize
          @emitted_events = []
        end

        # Override emit to capture events (accepts symbol + kwargs or event object)
        def emit(event_or_name, **)
          event = if event_or_name.is_a?(Symbol)
                    Smolagents::Events::Mappings.resolve(event_or_name).create(**)
                  else
                    event_or_name
                  end
          @emitted_events << event
          event
        end
      end
    end

    let(:emitter_consumer) { emitter_consumer_class.new }

    it "emits error event when handler fails" do
      emitter_consumer.on(Smolagents::Events::ToolCallCompleted) { raise ArgumentError, "handler failed" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      emitter_consumer.consume(event)

      error_events = emitter_consumer.emitted_events.select { |e| e.is_a?(Smolagents::Events::ErrorOccurred) }
      expect(error_events.size).to eq(1)

      error_event = error_events.first
      expect(error_event.error_class).to eq("ArgumentError")
      expect(error_event.error_message).to eq("handler failed")
      expect(error_event.recoverable).to be true
      expect(error_event.context[:event_class]).to eq("Smolagents::Events::ToolCallCompleted")
    end
  end

  describe "#shutdown_events" do
    it "shuts down the async queue" do
      Smolagents::Events::AsyncQueue.start

      result = consumer.shutdown_events(timeout: 1)

      expect(result).to be true
      expect(Smolagents::Events::AsyncQueue.running?).to be false
    end
  end
end
