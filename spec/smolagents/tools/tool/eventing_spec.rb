require "spec_helper"

RSpec.describe Smolagents::Tools::Tool::Eventing do
  let(:queue) { Thread::Queue.new }

  let(:test_tool_class) do
    Class.new(Smolagents::Tools::Tool) do
      self.tool_name = "test_tool"
      self.description = "A test tool"
      self.inputs = { value: { type: "integer", description: "A value" } }
      self.output_type = "integer"

      def execute(value:)
        value * 2
      end
    end
  end

  let(:tool) { test_tool_class.new }

  after { Smolagents::Events::AsyncQueue.reset! }

  describe "#emit_tool_call_requested" do
    context "when not connected to queue" do
      it "does not emit events" do
        tool.call(value: 5)
        expect(queue.size).to eq(0)
      end

      it "executes normally" do
        result = tool.call(value: 5)
        expect(result.data).to eq(10)
      end
    end

    context "when connected to queue" do
      before { tool.connect_to(queue) }

      it "emits ToolCallRequested event" do
        tool.call(value: 5)
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ToolCallRequested) }

        expect(requested).not_to be_nil
        expect(requested.tool_name).to eq("test_tool")
      end

      it "includes arguments in the event" do
        tool.call(value: 42)
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ToolCallRequested) }

        expect(requested.args).to eq({ value: 42 })
      end

      it "freezes arguments for immutability" do
        tool.call(value: 7)
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ToolCallRequested) }

        expect(requested.args).to be_frozen
      end

      it "handles hash-style argument passing" do
        tool.call({ value: 100 })
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ToolCallRequested) }

        expect(requested.args).to eq({ value: 100 })
      end
    end
  end

  describe "#emitting?" do
    it "returns false when not connected" do
      expect(tool.emitting?).to be false
    end

    it "returns true when connected" do
      tool.connect_to(queue)
      expect(tool.emitting?).to be true
    end
  end

  describe "integration with tool execution" do
    before { tool.connect_to(queue) }

    it "emits event before execution" do
      execution_order = []

      allow(tool).to receive(:execute).and_wrap_original do |method, **kwargs|
        execution_order << :execute
        method.call(**kwargs)
      end

      original_emit = tool.method(:emit)
      allow(tool).to receive(:emit) do |event|
        execution_order << :emit if event.is_a?(Smolagents::Events::ToolCallRequested)
        original_emit.call(event)
      end

      tool.call(value: 3)

      expect(execution_order).to eq(%i[emit execute])
    end

    it "does not block execution if event emission fails" do
      allow(tool).to receive(:emit).and_raise(StandardError.new("Queue error"))

      # Should still raise since emit is being called directly
      expect { tool.call(value: 5) }.to raise_error(StandardError, "Queue error")
    end
  end

  def drain_queue(event_queue)
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end
end
