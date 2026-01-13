require "spec_helper"

RSpec.describe Smolagents::Events::Consumer do
  let(:consumer_class) do
    Class.new do
      include Smolagents::Events::Consumer

      def initialize
        setup_consumer
      end
    end
  end

  let(:consumer) { consumer_class.new }

  describe "#on" do
    it "registers handler for event class" do
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| }
      expect(consumer.handles?(Smolagents::Events::ToolCallCompleted)).to be true
    end

    it "registers handler for convenience name" do
      consumer.on(:tool_complete) { |e| }
      expect(consumer.handles?(Smolagents::Events::ToolCallCompleted)).to be true
    end

    it "returns self for chaining" do
      result = consumer.on(Smolagents::Events::ToolCallCompleted) {}
      expect(result).to eq(consumer)
    end
  end

  describe "#on_any_event" do
    it "registers catch-all handler" do
      handled = []
      consumer.on_any_event { |e| handled << e }

      event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "test",
        result: "ok",
        observation: "done"
      )

      consumer.consume(event)

      expect(handled).to eq([event])
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
  end

  describe "filtering" do
    it "supports filter predicate" do
      results = []
      consumer.on(
        Smolagents::Events::ToolCallCompleted,
        filter: ->(e) { e.tool_name == "search" }
      ) { |e| results << e.tool_name }

      search_event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-1",
        tool_name: "search",
        result: "ok",
        observation: "done"
      )

      other_event = Smolagents::Events::ToolCallCompleted.create(
        request_id: "req-2",
        tool_name: "calculator",
        result: "42",
        observation: "done"
      )

      consumer.consume(search_event)
      consumer.consume(other_event)

      expect(results).to eq(["search"])
    end
  end

  describe "#consume_batch" do
    it "processes multiple events" do
      results = []
      consumer.on(Smolagents::Events::ToolCallCompleted) { |e| results << e.tool_name }

      events = Array.new(3) do |i|
        Smolagents::Events::ToolCallCompleted.create(
          request_id: "req-#{i}",
          tool_name: "tool_#{i}",
          result: "ok",
          observation: "done"
        )
      end

      batch_results = consumer.consume_batch(events)

      expect(results).to eq(%w[tool_0 tool_1 tool_2])
      expect(batch_results.keys).to eq(events)
    end
  end

  describe "#handler_count" do
    it "counts all registered handlers" do
      consumer.on(Smolagents::Events::ToolCallCompleted) {}
      consumer.on(Smolagents::Events::ToolCallCompleted) {}
      consumer.on(Smolagents::Events::ErrorOccurred) {}
      consumer.on_any_event {}

      expect(consumer.handler_count).to eq(4)
    end
  end

  describe "#clear_handlers" do
    it "removes all handlers" do
      consumer.on(Smolagents::Events::ToolCallCompleted) {}
      consumer.on_any_event {}

      consumer.clear_handlers

      expect(consumer.handler_count).to eq(0)
    end
  end
end
