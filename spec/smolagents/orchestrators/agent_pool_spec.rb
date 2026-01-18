require "spec_helper"

RSpec.describe Smolagents::Orchestrators::AgentPool do
  let(:mock_run_result) do
    instance_double(
      Smolagents::Types::RunResult,
      output: "Agent output",
      steps: [1, 2],
      success?: true
    )
  end

  let(:mock_agent) do
    instance_double(Smolagents::Agents::Agent).tap do |agent|
      allow(agent).to receive(:run).and_return(mock_run_result)
    end
  end

  let(:slow_agent) do
    instance_double(Smolagents::Agents::Agent).tap do |agent|
      allow(agent).to receive(:run) do
        sleep(0.05) # rubocop:disable Smolagents/NoSleep -- simulates slow agent
        mock_run_result
      end
    end
  end

  let(:failing_agent) do
    instance_double(Smolagents::Agents::Agent).tap do |agent|
      allow(agent).to receive(:run).and_raise(RuntimeError, "Agent failed")
    end
  end

  let(:agents) { { "researcher" => mock_agent, "analyzer" => mock_agent } }
  let(:pool) { described_class.new(agents:) }

  describe "#initialize" do
    it "stores agents and max_concurrent" do
      pool = described_class.new(agents:, max_concurrent: 8)

      expect(pool.agents).to eq(agents)
      expect(pool.max_concurrent).to eq(8)
    end

    it "freezes the agents hash" do
      expect(pool.agents).to be_frozen
    end

    it "defaults max_concurrent to 4" do
      expect(pool.max_concurrent).to eq(4)
    end
  end

  describe "#execute_single" do
    it "executes a single agent task" do
      result = pool.execute_single(agent_name: "researcher", prompt: "Find info")

      expect(result).to be_success
      expect(result.output).to eq("Agent output")
    end

    it "raises ArgumentError for unknown agent" do
      expect do
        pool.execute_single(agent_name: "unknown", prompt: "test")
      end.to raise_error(ArgumentError, /Unknown agent/)
    end

    it "captures failures" do
      pool = described_class.new(agents: { "failing" => failing_agent })

      result = pool.execute_single(agent_name: "failing", prompt: "test")

      expect(result).to be_failure
      expect(result.error.message).to eq("Agent failed")
    end

    it "respects timeout" do
      pool = described_class.new(agents: { "slow" => slow_agent })

      result = pool.execute_single(agent_name: "slow", prompt: "test", timeout: 0.01)

      expect(result).to be_failure
      expect(result.error).to be_a(Smolagents::TimeoutError)
    end
  end

  describe "#execute_parallel" do
    it "executes multiple agents in parallel" do
      tasks = [
        ["researcher", "Research topic A", {}],
        ["analyzer", "Analyze data B", {}]
      ]

      result = pool.execute_parallel(tasks:, timeout: 10)

      expect(result).to be_a(Smolagents::Orchestrators::PoolResult)
      expect(result.total_count).to eq(2)
      expect(result.success_count).to eq(2)
      expect(result).to be_all_succeeded
    end

    it "runs faster than sequential execution", :slow do
      # Each agent takes 50ms
      pool = described_class.new(
        agents: { "a" => slow_agent, "b" => slow_agent },
        max_concurrent: 2
      )

      tasks = [["a", "task 1", {}], ["b", "task 2", {}]]

      start = Time.now
      pool.execute_parallel(tasks:, timeout: 5)
      elapsed = Time.now - start

      # Parallel should be ~50ms, sequential would be ~100ms
      expect(elapsed).to be < 0.1
    end

    it "handles mixed success and failure" do
      pool = described_class.new(
        agents: { "good" => mock_agent, "bad" => failing_agent }
      )

      tasks = [["good", "test", {}], ["bad", "test", {}]]
      result = pool.execute_parallel(tasks:)

      expect(result.success_count).to eq(1)
      expect(result.failure_count).to eq(1)
      expect(result).to be_any_failed
    end

    it "respects max_concurrent for batching" do
      pool = described_class.new(agents:, max_concurrent: 1)

      tasks = [
        ["researcher", "task 1", {}],
        ["analyzer", "task 2", {}]
      ]

      result = pool.execute_parallel(tasks:)

      expect(result.total_count).to eq(2)
    end
  end

  describe Smolagents::Orchestrators::TaskResult do
    describe ".success" do
      it "creates a success result" do
        result = described_class.success(run_result: mock_run_result, duration: 1.5)

        expect(result).to be_success
        expect(result).not_to be_failure
        expect(result.output).to eq("Agent output")
        expect(result.duration).to eq(1.5)
      end
    end

    describe ".failure" do
      it "creates a failure result" do
        error = RuntimeError.new("oops")
        result = described_class.failure(error:)

        expect(result).to be_failure
        expect(result).not_to be_success
        expect(result.error).to eq(error)
        expect(result.output).to be_nil
      end
    end
  end

  describe Smolagents::Orchestrators::PoolResult do
    let(:success1) { Smolagents::Orchestrators::TaskResult.success(run_result: mock_run_result, duration: 1.0) }
    let(:success2) { Smolagents::Orchestrators::TaskResult.success(run_result: mock_run_result, duration: 2.0) }
    let(:failure1) { Smolagents::Orchestrators::TaskResult.failure(error: RuntimeError.new("err")) }

    it "aggregates results" do
      result = described_class.new(results: [success1, success2, failure1], duration: 3.0)

      expect(result.total_count).to eq(3)
      expect(result.success_count).to eq(2)
      expect(result.failure_count).to eq(1)
      expect(result.duration).to eq(3.0)
    end

    it "provides success/failure predicates" do
      all_success = described_class.new(results: [success1, success2], duration: 1.0)
      mixed = described_class.new(results: [success1, failure1], duration: 1.0)

      expect(all_success).to be_all_succeeded
      expect(all_success).not_to be_any_failed

      expect(mixed).not_to be_all_succeeded
      expect(mixed).to be_any_failed
    end

    it "filters successes and failures" do
      result = described_class.new(results: [success1, failure1, success2], duration: 1.0)

      expect(result.successes).to eq([success1, success2])
      expect(result.failures).to eq([failure1])
    end
  end
end
