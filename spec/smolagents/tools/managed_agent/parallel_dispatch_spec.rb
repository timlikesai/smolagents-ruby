require "smolagents"
require "smolagents/tools/managed_agent/parallel_dispatch"

RSpec.describe Smolagents::Tools::ManagedAgentTool::ParallelDispatch do
  let(:dispatcher) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      # Enable event emission via a queue so events are captured
      obj.connect_to(event_queue)
    end
  end

  let(:event_queue) { Thread::Queue.new }

  let(:mock_result) do
    double("RunResult",
           state: :success, output: "done", token_usage: nil,
           step_count: 1, duration: 0.1)
  end

  let(:agent1) do
    double("Agent1", name: "agent1", run: mock_result)
  end

  let(:agent2) do
    double("Agent2", name: "agent2", run: mock_result)
  end

  def drain_events
    event_queue.close
    events = []
    while (event = event_queue.pop)
      events << event
    end
    events
  end

  describe "#execute_parallel", :slow do
    context "with a single agent" do
      it "executes and returns result" do
        tasks = [{ agent: agent1, task: "do something" }]

        results = dispatcher.execute_parallel(tasks)

        expect(results.size).to eq(1)
        expect(results.first[:agent_name]).to eq("agent1")
        expect(results.first[:outcome]).to eq(:success)
        expect(results.first[:output]).to eq("done")
        expect(results.first[:error]).to be_nil
      end
    end

    context "with multiple agents" do
      it "executes all and returns results" do
        tasks = [
          { agent: agent1, task: "task1" },
          { agent: agent2, task: "task2" }
        ]

        results = dispatcher.execute_parallel(tasks)

        expect(results.size).to eq(2)
        names = results.map { |r| r[:agent_name] }
        expect(names).to contain_exactly("agent1", "agent2")
        expect(results).to all(include(outcome: :success))
      end
    end

    context "with error isolation" do
      it "isolates failures so one agent error does not crash others" do
        failing_agent = double("FailingAgent", name: "failing")
        allow(failing_agent).to receive(:run).and_raise(StandardError, "boom")

        tasks = [
          { agent: agent1, task: "task1" },
          { agent: failing_agent, task: "task2" }
        ]

        results = dispatcher.execute_parallel(tasks)

        expect(results.size).to eq(2)

        success = results.find { |r| r[:agent_name] == "agent1" }
        failure = results.find { |r| r[:agent_name] == "failing" }

        expect(success[:outcome]).to eq(:success)
        expect(failure[:outcome]).to eq(:error)
        expect(failure[:error]).to eq("boom")
        expect(failure[:output]).to be_nil
      end
    end
  end

  describe "#agent_name_for (via execute_parallel)", :slow do
    it "uses name method when available" do
      named = double("NamedAgent", name: "custom_name", run: mock_result)
      tasks = [{ agent: named, task: "t" }]

      results = dispatcher.execute_parallel(tasks)

      expect(results.first[:agent_name]).to eq("custom_name")
    end

    it "falls back to class name when name method is absent" do
      nameless = Object.new
      def nameless.run(_task)
        result = Data.define(:state, :output, :token_usage, :step_count, :duration)
        result.new(:success, "ok", nil, 0, 0.0)
      end

      tasks = [{ agent: nameless, task: "t" }]

      results = dispatcher.execute_parallel(tasks)

      expect(results.first[:agent_name]).to eq("Object")
    end
  end

  describe "event emission", :slow do
    it "emits SubAgentLaunched for each agent" do
      tasks = [{ agent: agent1, task: "task1" }]

      dispatcher.execute_parallel(tasks)
      events = drain_events

      launched = events.select { |e| e.is_a?(Smolagents::Events::SubAgentLaunched) }
      expect(launched.size).to eq(1)
      expect(launched.first.agent_name).to eq("agent1")
      expect(launched.first.task).to eq("task1")
    end

    it "emits SubAgentCompleted for each agent" do
      tasks = [{ agent: agent1, task: "task1" }]

      dispatcher.execute_parallel(tasks)
      events = drain_events

      completed = events.select { |e| e.is_a?(Smolagents::Events::SubAgentCompleted) }
      expect(completed.size).to eq(1)
      expect(completed.first.agent_name).to eq("agent1")
      expect(completed.first.outcome).to eq(:success)
    end

    it "emits events for all agents in parallel execution" do
      tasks = [
        { agent: agent1, task: "task1" },
        { agent: agent2, task: "task2" }
      ]

      dispatcher.execute_parallel(tasks)
      events = drain_events

      launched = events.select { |e| e.is_a?(Smolagents::Events::SubAgentLaunched) }
      completed = events.select { |e| e.is_a?(Smolagents::Events::SubAgentCompleted) }

      expect(launched.size).to eq(2)
      expect(completed.size).to eq(2)
    end
  end
end
