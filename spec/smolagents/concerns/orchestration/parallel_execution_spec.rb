require "smolagents"

RSpec.describe Smolagents::Concerns::Orchestration::ParallelExecution do
  let(:executor) { Object.new.extend(described_class) }
  let(:agent_result) do
    instance_double(Smolagents::RunResult, state: :success, output: "result")
  end
  let(:agent) { build_mock_agent(name: "TestAgent", result: agent_result) }
  let(:tasks) { [{ agent:, task: "Do something" }] }
  let(:parallel_stage) { double("Stage", parallel?: true, tasks:) }
  let(:sequential_stage) { double("Stage", parallel?: false, tasks:) }

  def build_mock_agent(name:, result: nil, error: nil)
    klass = Class.new { define_method(:name) { name } }
    agent = klass.new
    if error
      allow(agent).to receive(:run).and_raise(StandardError, error)
    else
      allow(agent).to receive(:run).and_return(result)
    end
    agent
  end

  describe "#execute_stage routing" do
    it "returns results from sequential stage" do
      results = executor.execute_stage(sequential_stage)

      expect(results.size).to eq(1)
      expect(results.first).to include(outcome: :success)
    end

    it "treats stage without parallel? method as sequential" do
      plain_stage = double("PlainStage", tasks:)

      results = executor.execute_stage(plain_stage)

      expect(results.size).to eq(1)
      expect(results.first).to include(outcome: :success)
    end
  end

  describe "sequential execution" do
    it "executes each agent in order" do
      agent2_result = instance_double(Smolagents::RunResult, state: :success, output: "result2")
      agent2 = build_mock_agent(name: "Agent2", result: agent2_result)

      multi_tasks = [
        { agent:, task: "Task 1" },
        { agent: agent2, task: "Task 2" }
      ]
      stage = double("Stage", parallel?: false, tasks: multi_tasks)

      results = executor.execute_stage(stage)

      expect(results.size).to eq(2)
      expect(results[0]).to include(outcome: :success, output: "result")
      expect(results[1]).to include(outcome: :success, output: "result2")
    end

    it "captures errors per agent" do
      failing_agent = build_mock_agent(name: "FailAgent", error: "task failed")

      multi_tasks = [
        { agent:, task: "Task 1" },
        { agent: failing_agent, task: "Task 2" }
      ]
      stage = double("Stage", parallel?: false, tasks: multi_tasks)

      results = executor.execute_stage(stage)

      expect(results.size).to eq(2)
      expect(results[0][:outcome]).to eq(:success)
      expect(results[1]).to include(outcome: :error, error: "task failed")
    end
  end

  describe "empty tasks" do
    it "returns empty array for parallel stage with no tasks" do
      empty_stage = double("Stage", parallel?: true, tasks: [])

      expect(executor.execute_stage(empty_stage)).to eq([])
    end

    it "returns empty array for sequential stage with no tasks" do
      empty_stage = double("Stage", parallel?: false, tasks: [])

      expect(executor.execute_stage(empty_stage)).to eq([])
    end
  end

  describe "parallel execution", :slow do
    it "dispatches tasks via ParallelDispatch" do
      mock_result = instance_double(
        Smolagents::RunResult,
        state: :success, output: "done", token_usage: nil, step_count: 1, duration: 0.1
      )
      par_agent = build_mock_agent(name: "ParAgent", result: mock_result)
      par_tasks = [{ agent: par_agent, task: "parallel task" }]
      par_stage = double("Stage", parallel?: true, tasks: par_tasks)

      results = executor.execute_stage(par_stage)

      expect(results.size).to eq(1)
      expect(results.first).to include(agent_name: "ParAgent", outcome: :success)
    end
  end
end
