RSpec.describe Smolagents::Orchestrators::RactorOrchestrator do
  let(:mock_run_result) do
    double("RunResult",
           output: "Agent output",
           steps: [1, 2],
           token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50),
           success?: true)
  end

  let(:mock_model) { double("Model", model_id: "test-model") }

  let(:mock_agent) do
    double("Agent",
           model: mock_model,
           tools: { "tool1" => double },
           max_steps: 10,
           run: mock_run_result)
  end

  let(:agents) { { "researcher" => mock_agent, "analyzer" => mock_agent } }
  let(:orchestrator) { described_class.new(agents: agents) }

  describe "#initialize" do
    it "stores agents and max_concurrent" do
      orch = described_class.new(agents: agents, max_concurrent: 8)

      expect(orch.agents).to eq(agents)
      expect(orch.max_concurrent).to eq(8)
    end

    it "freezes the agents hash" do
      expect(orchestrator.agents).to be_frozen
    end
  end

  describe "#execute_parallel", skip: "Requires Ractor environment" do
    it "executes multiple tasks in parallel" do
      tasks = [
        ["researcher", "Research topic A", {}],
        ["analyzer", "Analyze data B", {}]
      ]

      result = orchestrator.execute_parallel(tasks: tasks, timeout: 10)

      expect(result).to be_a(Smolagents::OrchestratorResult)
      expect(result.total_count).to eq(2)
    end
  end

  describe "#execute_single", skip: "Requires Ractor environment" do
    it "executes a single agent task" do
      result = orchestrator.execute_single(
        agent_name: "researcher",
        prompt: "Research something",
        timeout: 5
      )

      expect(result).to respond_to(:success?)
    end
  end

  describe "task creation" do
    it "creates RactorTasks from tuples" do
      orchestrator # Instantiate

      tasks = orchestrator.send(:create_ractor_tasks, [
                                  ["researcher", "Prompt 1", { max_steps: 5 }],
                                  ["analyzer", "Prompt 2", nil]
                                ])

      expect(tasks.size).to eq(2)
      expect(tasks[0]).to be_a(Smolagents::RactorTask)
      expect(tasks[0].agent_name).to eq("researcher")
      expect(tasks[0].prompt).to eq("Prompt 1")
      expect(tasks[1].agent_name).to eq("analyzer")
    end
  end

  describe "agent config preparation" do
    it "prepares agent config for Ractor" do
      task = Smolagents::RactorTask.create(
        agent_name: "researcher",
        prompt: "test",
        config: { max_steps: 15 }
      )

      config = orchestrator.send(:prepare_agent_config, mock_agent, task)

      expect(config).to be_frozen
      expect(config[:model_class]).to be_a(String)
      expect(config[:model_id]).to eq("test-model")
      expect(config[:max_steps]).to eq(15)
      expect(config[:tool_names]).to eq(["tool1"])
    end
  end

  describe "result building" do
    it "builds OrchestratorResult from results" do
      mock_result = double("RunResult", output: "out", steps: [1], token_usage: nil)
      success = Smolagents::RactorSuccess.from_result(
        task_id: "1", run_result: mock_result, duration: 1.0, trace_id: "t1"
      )
      failure = Smolagents::RactorFailure.from_exception(
        task_id: "2", error: RuntimeError.new("err"), trace_id: "t2"
      )

      result = orchestrator.send(:build_orchestrator_result, [success, failure], 2.5)

      expect(result).to be_a(Smolagents::OrchestratorResult)
      expect(result.success_count).to eq(1)
      expect(result.failure_count).to eq(1)
      expect(result.duration).to eq(2.5)
    end
  end

  describe "error handling" do
    it "raises ArgumentError for unknown agent" do
      expect do
        orchestrator.send(:spawn_agent_ractor, Smolagents::RactorTask.create(agent_name: "unknown", prompt: "test"))
      end.to raise_error(ArgumentError, /Unknown agent/)
    end
  end
end
