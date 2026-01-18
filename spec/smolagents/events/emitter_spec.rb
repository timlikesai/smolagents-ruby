require "spec_helper"

RSpec.describe Smolagents::Events::Emitter do
  let(:queue) { Thread::Queue.new }

  let(:emitter_class) do
    Class.new do
      include Smolagents::Events::Emitter

      def name
        "test_tool"
      end
    end
  end

  let(:emitter) { emitter_class.new }

  after do
    Smolagents::Events::AsyncQueue.reset!
  end

  describe "#connect_to" do
    it "sets the event queue" do
      emitter.connect_to(queue)

      expect(emitter.event_queue).to eq(queue)
    end

    it "returns self for chaining" do
      result = emitter.connect_to(queue)

      expect(result).to eq(emitter)
    end
  end

  describe "#emit" do
    context "with connected queue" do
      before { emitter.connect_to(queue) }

      it "pushes event to queue" do
        event = Smolagents::Events::ToolCallRequested.create(
          tool_name: "test",
          args: {}
        )

        emitter.emit(event)

        expect(queue.size).to eq(1)
      end

      it "returns the emitted event" do
        event = Smolagents::Events::ToolCallRequested.create(
          tool_name: "test",
          args: {}
        )

        result = emitter.emit(event)

        expect(result).to eq(event)
      end
    end

    it "does nothing when not connected and no handlers" do
      event = Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})

      result = emitter.emit(event)

      expect(result).to eq(event)
      expect(queue.size).to eq(0)
    end
  end

  describe "#emit_sync" do
    context "with connected queue" do
      before { emitter.connect_to(queue) }

      it "pushes event to queue" do
        event = Smolagents::Events::ToolCallRequested.create(
          tool_name: "test",
          args: {}
        )

        emitter.emit_sync(event)

        expect(queue.size).to eq(1)
      end
    end

    it "returns the emitted event" do
      event = Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})

      result = emitter.emit_sync(event)

      expect(result).to eq(event)
    end
  end

  describe "#emit_event (alias)" do
    before { emitter.connect_to(queue) }

    it "is an alias for emit" do
      event = Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})

      emitter.emit_event(event)

      expect(queue.size).to eq(1)
    end
  end

  describe "#emit_error" do
    before { emitter.connect_to(queue) }

    it "creates and emits error event" do
      error = StandardError.new("Something failed")

      event = emitter.emit_error(error, context: { step: 1 })

      expect(event).to be_a(Smolagents::Events::ErrorOccurred)
      expect(event.error_class).to eq("StandardError")
      expect(event.error_message).to eq("Something failed")
      expect(event.recoverable?).to be false
      expect(queue.size).to eq(1)
    end

    it "supports recoverable errors" do
      error = StandardError.new("Transient")

      event = emitter.emit_error(error, recoverable: true)

      expect(event.recoverable?).to be true
    end
  end

  describe "#emitting?" do
    it "returns false when not connected" do
      expect(emitter.emitting?).to be false
    end

    it "returns true when connected" do
      emitter.connect_to(queue)

      expect(emitter.emitting?).to be true
    end
  end

  describe "async emit with local handlers" do
    let(:combined_class) do
      Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Events::Consumer
      end
    end

    let(:combined) { combined_class.new }

    it "processes events asynchronously when handlers registered", :slow do
      results = []
      mutex = Mutex.new

      combined.on(Smolagents::Events::ToolCallRequested) do |e|
        mutex.synchronize { results << e.tool_name }
      end

      event = Smolagents::Events::ToolCallRequested.create(
        tool_name: "async_test",
        args: {}
      )

      combined.emit(event)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(results).to eq(["async_test"])
    end

    it "emit_sync processes synchronously" do
      results = []

      combined.on(Smolagents::Events::ToolCallRequested) do |e|
        results << e.tool_name
      end

      event = Smolagents::Events::ToolCallRequested.create(
        tool_name: "sync_test",
        args: {}
      )

      combined.emit_sync(event)

      expect(results).to eq(["sync_test"]) # Immediate, no sleep needed
    end
  end
end
