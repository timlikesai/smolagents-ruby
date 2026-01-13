require "spec_helper"

RSpec.describe Smolagents::Events::Consumer do
  let(:consumer_class) do
    Class.new do
      include Smolagents::Events::Consumer
    end
  end

  let(:consumer) { consumer_class.new }

  describe "#on" do
    it "registers handler for event class" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { |_e| }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ToolCallCompleted)
    end

    it "registers handler for convenience name" do
      consumer.on(:tool_complete) { |_e| }
      expect(consumer.event_handlers).to have_key(Smolagents::Events::ToolCallCompleted)
    end

    it "returns self for chaining" do
      result = consumer.on(Smolagents::Events::ToolCallCompleted) {}
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

    it "handles errors gracefully" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { raise "boom" }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      expect { consumer.consume(event) }.not_to raise_error
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
  end

  describe "#clear_handlers" do
    it "removes all handlers" do
      consumer.on(Smolagents::Events::ToolCallCompleted) {}
      consumer.on(Smolagents::Events::ErrorOccurred) {}

      consumer.clear_handlers

      expect(consumer.event_handlers).to be_empty
    end

    it "returns self for chaining" do
      result = consumer.clear_handlers
      expect(result).to eq(consumer)
    end
  end
end
