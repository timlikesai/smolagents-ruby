require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test for Emitter + Consumer modules
RSpec.describe "Events::Emitter + Events::Consumer integration" do
  let(:component_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
    end
  end

  let(:component) { component_class.new }

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  describe "symbol-based emission" do
    it "emits events using symbol names" do
      received = []
      component.on(:step_completed) { |e| received << e }

      component.emit :step_completed, step_number: 1, outcome: :success

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      expect(received.first.step_number).to eq(1)
      expect(received.first.outcome).to eq(:success)
    end

    it "returns the created event" do
      component.on(:step_completed) { |_e| nil } # Handler needed to trigger emission

      event = component.emit :step_completed, step_number: 1, outcome: :success

      expect(event).to be_a(Smolagents::Events::StepCompleted)
      expect(event.step_number).to eq(1)
    end

    it "supports all mapped event types" do
      received = []
      component.on(:tool_call_completed) { |e| received << e }

      component.emit :tool_call_completed,
                     request_id: "r1", tool_name: "search",
                     result: "data", observation: "found"

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.tool_name).to eq("search")
    end
  end

  describe "legacy object emission" do
    it "accepts pre-built event objects" do
      received = []
      component.on(:step_completed) { |e| received << e }

      event = Smolagents::Events::StepCompleted.create(step_number: 2, outcome: :error)
      component.emit event

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first).to eq(event)
    end
  end

  describe "block-based timing" do
    it "captures duration_ms when block given", :slow do
      received = []
      component.on(:model_generation) { |e| received << e }

      # rubocop:disable Smolagents/NoSleep -- testing timing capture requires actual delay
      result = component.emit(:model_generation, phase: :completed, model_id: "gpt-4") do
        sleep 0.01
        "response"
      end
      # rubocop:enable Smolagents/NoSleep

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(result).to eq("response")
      expect(received.first.duration_ms).to be >= 10
    end

    it "still emits event if block raises" do
      received = []
      component.on(:model_generation) { |e| received << e }

      expect do
        component.emit(:model_generation, phase: :completed, model_id: "gpt-4") do
          raise "boom"
        end
      end.to raise_error("boom")

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
    end
  end

  describe "synchronous emission with emit!" do
    it "calls handlers synchronously" do
      order = []
      component.on(:step_completed) { |_e| order << :handler }

      component.emit! :step_completed, step_number: 1, outcome: :success
      order << :after_emit

      expect(order).to eq(%i[handler after_emit])
    end
  end

  describe "multi-event subscription" do
    it "subscribes to multiple events at once" do
      received = []
      component.on(:step_completed, :task_lifecycle) { |e| received << e.class.name }

      component.emit :step_completed, step_number: 1, outcome: :success
      component.emit :task_lifecycle, phase: :completed, outcome: :success, output: "done", steps_taken: 1

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received).to contain_exactly(
        "Smolagents::Events::StepCompleted",
        "Smolagents::Events::TaskLifecycle"
      )
    end
  end

  describe "keyword destructuring in handlers" do
    it "passes event fields as kwargs when handler expects them" do
      captured_step = nil
      captured_outcome = nil

      component.on(:step_completed) do |step_number:, outcome:, **|
        captured_step = step_number
        captured_outcome = outcome
      end

      component.emit :step_completed, step_number: 42, outcome: :success

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(captured_step).to eq(42)
      expect(captured_outcome).to eq(:success)
    end

    it "still works with positional handlers" do
      captured = nil
      component.on(:step_completed) { |e| captured = e }

      component.emit :step_completed, step_number: 1, outcome: :success

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(captured).to be_a(Smolagents::Events::StepCompleted)
    end
  end

  describe "category subscriptions" do
    describe "#on_tools" do
      it "subscribes to all tool events" do
        received = []
        component.on_tools { |e| received << e.class.name.split("::").last }

        component.emit :tool_call_requested, tool_name: "search", args: {}
        component.emit :tool_call_completed,
                       request_id: "r1", tool_name: "search",
                       result: "data", observation: "ok"

        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(received).to include("ToolCallRequested", "ToolCallCompleted")
      end
    end

    describe "#on_lifecycle" do
      it "subscribes to step and task events" do
        received = []
        component.on_lifecycle { |e| received << e.class.name.split("::").last }

        component.emit :step_completed, step_number: 1, outcome: :success
        component.emit :task_lifecycle, phase: :completed, outcome: :success, output: "done", steps_taken: 1

        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(received).to contain_exactly("StepCompleted", "TaskLifecycle")
      end
    end

    describe "#on_errors" do
      it "subscribes to error events" do
        received = []
        component.on_errors { |e| received << e.class.name.split("::").last }

        component.emit_error(StandardError.new("oops"))

        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(received).to include("ErrorOccurred")
      end
    end

    describe "#on_models" do
      it "subscribes to model events" do
        received = []
        component.on_models { |e| received << e.phase }

        component.emit :model_generation, phase: :requested, model_id: "gpt-4", message_count: 1
        component.emit :model_generation, phase: :completed, model_id: "gpt-4", duration_ms: 100

        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(received).to contain_exactly(:requested, :completed)
      end
    end
  end

  describe "no-op when not emitting" do
    it "returns event name symbol when no handlers and no queue" do
      fresh = component_class.new
      result = fresh.emit :step_completed, step_number: 1, outcome: :success

      # When not emitting, returns the input unchanged (no event built)
      expect(result).to eq(:step_completed)
    end

    it "emitting? returns false when inactive" do
      fresh = component_class.new
      expect(fresh.emitting?).to be(false)
    end

    it "emitting? returns true when handlers registered" do
      component.on(:step_completed) { |_e| nil }
      expect(component.emitting?).to be(true)
    end

    it "still executes block even when not emitting" do
      fresh = component_class.new
      executed = false

      result = fresh.emit(:model_generation, phase: :completed, model_id: "gpt-4") do
        executed = true
        "response"
      end

      expect(executed).to be true
      expect(result).to eq("response")
    end
  end

  describe "#emit_error" do
    it "creates error event from exception" do
      received = []
      component.on(:error_occurred) { |e| received << e }

      error = StandardError.new("something went wrong")
      component.emit_error(error, context: { step: 1 }, recoverable: true)

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.error_class).to eq("StandardError")
      expect(received.first.error_message).to eq("something went wrong")
      expect(received.first.context).to eq({ step: 1 })
      expect(received.first).to be_recoverable
    end
  end

  describe "handler error resilience" do
    it "continues processing after handler error" do
      results = []
      component.on(:step_completed) { |_e| raise "handler 1 failed" }
      component.on(:step_completed) { |_e| results << "handler 2 ok" }

      component.emit! :step_completed, step_number: 1, outcome: :success

      expect(results).to eq(["handler 2 ok"])
      expect(component.handlers_failed?).to be true
    end

    it "records failed handlers" do
      component.on(:step_completed) { |_e| raise "boom" }

      component.emit! :step_completed, step_number: 1, outcome: :success

      expect(component.failed_handlers.size).to eq(1)
      expect(component.failed_handlers.first.error.message).to eq("boom")
    end
  end

  describe "#clear_handlers" do
    it "removes all handlers" do
      component.on(:step_completed) { |_e| nil }
      expect(component.event_handlers).not_to be_empty

      component.clear_handlers

      expect(component.event_handlers).to be_empty
    end
  end

  describe "external queue connection" do
    it "pushes events to connected queue" do
      queue = Thread::Queue.new
      component.connect_to(queue)

      component.emit :step_completed, step_number: 1, outcome: :success

      event = queue.pop(true)
      expect(event).to be_a(Smolagents::Events::StepCompleted)
    end
  end

  describe "chaining" do
    it "returns self from subscription methods" do
      result = component
               .on(:step_completed) { |_e| nil }
               .on(:task_lifecycle) { |_e| nil }
               .on_tools { |_e| nil }

      expect(result).to eq(component)
    end
  end

  describe "event serialization" do
    it "provides event_name for human-readable identification" do
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)

      expect(event.event_name).to eq("step_completed")
      expect(Smolagents::Events::StepCompleted.event_name).to eq("step_completed")
    end

    it "provides field_names excluding metadata" do
      fields = Smolagents::Events::StepCompleted.field_names

      expect(fields).to contain_exactly(:step_number, :outcome, :observations, :token_usage, :context_usage_percent)
      expect(fields).not_to include(:id, :sequence, :created_at)
    end

    it "serializes to JSON with type information" do
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
      json = JSON.parse(event.to_json)

      expect(json["_type"]).to eq("Smolagents::Events::StepCompleted")
      expect(json["step_number"]).to eq(1)
      expect(json["outcome"]).to eq("success")
    end

    it "provides as_log_entry for structured logging" do
      event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
      entry = event.as_log_entry

      expect(entry[:event_type]).to eq("step_completed")
      expect(entry[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
      expect(entry[:step_number]).to eq(1)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
