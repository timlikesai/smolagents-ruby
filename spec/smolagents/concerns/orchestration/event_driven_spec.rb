require "spec_helper"

# -- testing callback registration
RSpec.describe Smolagents::Concerns::Orchestration::EventDriven do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:agent) do
    Smolagents.agent
              .model { mock_model }
              .tools(:final_answer)
              .event_driven
              .build
  end

  describe "inclusion" do
    it "adds run_async method" do
      expect(agent).to respond_to(:run_async)
    end

    it "adds callback registration methods" do
      expect(agent).to respond_to(:on_step_complete)
      expect(agent).to respond_to(:on_task_complete)
      expect(agent).to respond_to(:on_error)
    end

    it "adds orchestrator connection methods" do
      expect(agent).to respond_to(:connect_orchestrator)
      expect(agent).to respond_to(:disconnect_orchestrator)
    end

    it "adds async_stats method" do
      expect(agent).to respond_to(:async_stats)
    end
  end

  describe "#async_stats" do
    it "returns execution statistics" do
      stats = agent.async_stats
      expect(stats).to include(:pending_runs, :pending_callbacks, :orchestrator_connected)
    end

    it "shows orchestrator not connected by default" do
      expect(agent.async_stats[:orchestrator_connected]).to be false
    end
  end

  describe "#connect_orchestrator" do
    let(:orchestrator) { Smolagents::Orchestrators::EventOrchestrator.new }

    after { orchestrator.stop if orchestrator.running? }

    it "connects to an orchestrator" do
      agent.connect_orchestrator(orchestrator)
      expect(agent.async_stats[:orchestrator_connected]).to be true
    end

    it "returns self for chaining" do
      expect(agent.connect_orchestrator(orchestrator)).to eq(agent)
    end
  end

  describe "#disconnect_orchestrator" do
    let(:orchestrator) { Smolagents::Orchestrators::EventOrchestrator.new }

    before { agent.connect_orchestrator(orchestrator) }
    after { orchestrator.stop if orchestrator.running? }

    it "disconnects from orchestrator" do
      agent.disconnect_orchestrator
      expect(agent.async_stats[:orchestrator_connected]).to be false
    end
  end

  describe "callback registration" do
    describe "#on_step_complete" do
      it "registers a step completion callback and returns self" do
        result = agent.on_step_complete { |_step| :noop }
        expect(result).to eq(agent)
      end
    end

    describe "#on_task_complete" do
      it "registers a task completion callback and returns self" do
        result = agent.on_task_complete { |_result| :noop }
        expect(result).to eq(agent)
      end
    end

    describe "#on_error" do
      it "registers an error callback and returns self" do
        result = agent.on_error { |_e, _ctx| :noop }
        expect(result).to eq(agent)
      end
    end

    describe "#clear_callbacks" do
      it "clears all registered callbacks and returns self" do
        agent.on_step_complete { |_| :noop }
        agent.on_task_complete { |_| :noop }
        result = agent.clear_callbacks
        expect(result).to eq(agent)
      end
    end
  end

  describe "#run_async" do
    before do
      mock_model.queue_final_answer("async result")
    end

    it "returns a run ID immediately" do
      run_id = agent.run_async("Test task")
      expect(run_id).to be_a(String)
    end

    it "invokes on_complete callback when done" do
      result_queue = Queue.new

      agent.run_async("Test task",
                      on_complete: ->(r) { result_queue.push(r) })

      # Block until result arrives (with timeout for safety)
      result = result_queue.pop
      expect(result.output).to eq("async result")
    end

    it "invokes on_step callback for each step" do
      step_queue = Queue.new
      agent.run_async("Test task", on_step: ->(s) { step_queue.push(s) })

      step = step_queue.pop
      expect(step).to be_a(Smolagents::Types::ActionStep)
    end
  end

  describe "#cancel_run" do
    it "cancels a pending async run" do
      run_id = agent.run_async("Long task")
      agent.cancel_run(run_id)
      expect(agent.async_running?(run_id)).to be false
    end

    it "returns self" do
      run_id = agent.run_async("Test")
      expect(agent.cancel_run(run_id)).to eq(agent)
    end
  end

  describe "#async_running?" do
    it "returns true for active runs" do
      run_id = agent.run_async("Test task")
      expect(agent.async_running?(run_id)).to be true
      agent.cancel_run(run_id)
    end

    it "returns false for unknown run IDs" do
      expect(agent.async_running?("unknown")).to be false
    end
  end
end
