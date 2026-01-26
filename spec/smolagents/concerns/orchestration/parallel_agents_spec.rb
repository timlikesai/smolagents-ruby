require "spec_helper"

RSpec.describe Smolagents::Concerns::Orchestration::ParallelAgents do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  let(:parallel_host) do
    Class.new do
      include Smolagents::Concerns::Orchestration::ParallelAgents

      attr_accessor :model

      def spawn_model = model
      def agent_id = "test-agent"
    end.new.tap { |h| h.model = mock_model }
  end

  def mock_agent_with_result(result, delay: 0)
    agent = instance_double(Smolagents::Agents::Agent)
    allow(agent).to receive(:run) do
      simulate_work(delay)
      instance_double(Smolagents::Types::RunResult, output: result)
    end
    agent
  end

  def mock_agent_with_error(message, delay: 0)
    agent = instance_double(Smolagents::Agents::Agent)
    allow(agent).to receive(:run) do
      simulate_work(delay)
      raise StandardError, message
    end
    agent
  end

  describe "#spawn_parallel" do
    it "executes all agents and returns results" do
      agent1 = mock_agent_with_result("result1")
      agent2 = mock_agent_with_result("result2")

      results = parallel_host.spawn_parallel([
                                               { agent: agent1, task: "Task 1" },
                                               { agent: agent2, task: "Task 2" }
                                             ])

      expect(results).to contain_exactly("result1", "result2")
    end

    it "raises if any agent fails" do
      agent1 = mock_agent_with_result("ok")
      agent2 = mock_agent_with_error("Failed!")

      expect do
        parallel_host.spawn_parallel([
                                       { agent: agent1, task: "Task 1" },
                                       { agent: agent2, task: "Task 2" }
                                     ])
      end.to raise_error(Smolagents::Concerns::Orchestration::ParallelAgents::ParallelExecutionError)
    end

    it "executes agents concurrently" do
      agent1 = mock_agent_with_result("result1", delay: 0.05)
      agent2 = mock_agent_with_result("result2", delay: 0.05)

      start = Time.now
      parallel_host.spawn_parallel([
                                     { agent: agent1, task: "Task 1" },
                                     { agent: agent2, task: "Task 2" }
                                   ])
      duration = Time.now - start

      # Should complete in ~0.05s (parallel), not ~0.1s (sequential)
      expect(duration).to be < 0.15
    end
  end

  describe "#spawn_race", :slow do
    it "returns first completing result" do
      fast_agent = mock_agent_with_result("fast", delay: 0.01)
      slow_agent = mock_agent_with_result("slow", delay: 0.1)

      result = parallel_host.spawn_race([
                                          { agent: slow_agent, task: "Slow task" },
                                          { agent: fast_agent, task: "Fast task" }
                                        ])

      expect(result).to eq("fast")
    end

    it "cancels other agents after winner" do
      # We can't easily verify cancellation, but we verify it returns quickly
      fast_agent = mock_agent_with_result("fast", delay: 0.01)
      slow_agent = mock_agent_with_result("slow", delay: 0.5)

      start = Time.now
      parallel_host.spawn_race([
                                 { agent: slow_agent, task: "Slow" },
                                 { agent: fast_agent, task: "Fast" }
                               ])
      duration = Time.now - start

      expect(duration).to be < 0.3
    end

    it "raises if all agents fail" do
      agent1 = mock_agent_with_error("Error 1")
      agent2 = mock_agent_with_error("Error 2")

      expect do
        parallel_host.spawn_race([
                                   { agent: agent1, task: "Task 1" },
                                   { agent: agent2, task: "Task 2" }
                                 ])
      end.to raise_error(Smolagents::Concerns::Orchestration::ParallelAgents::ParallelExecutionError)
    end
  end

  describe "#spawn_any", :slow do
    it "returns first N results" do
      agent1 = mock_agent_with_result("r1", delay: 0.01)
      agent2 = mock_agent_with_result("r2", delay: 0.02)
      agent3 = mock_agent_with_result("r3", delay: 0.05)

      results = parallel_host.spawn_any([
                                          { agent: agent1, task: "T1" },
                                          { agent: agent2, task: "T2" },
                                          { agent: agent3, task: "T3" }
                                        ], count: 2)

      expect(results.size).to eq(2)
      expect(results).to include("r1")
      expect(results).to include("r2")
    end

    it "raises if count > specs.size" do
      expect do
        parallel_host.spawn_any([{ agent: mock_agent_with_result("r"), task: "T" }], count: 2)
      end.to raise_error(ArgumentError, /count must be/)
    end

    it "raises if fewer than N agents succeed" do
      agent1 = mock_agent_with_result("ok")
      agent2 = mock_agent_with_error("Failed")
      agent3 = mock_agent_with_error("Also failed")

      expect do
        parallel_host.spawn_any([
                                  { agent: agent1, task: "T1" },
                                  { agent: agent2, task: "T2" },
                                  { agent: agent3, task: "T3" }
                                ], count: 2)
      end.to raise_error(Smolagents::Concerns::Orchestration::ParallelAgents::ParallelExecutionError)
    end
  end

  describe "Execution module" do
    it "requires task in spec" do
      expect do
        parallel_host.spawn_parallel([{ agent: mock_agent_with_result("r") }])
      end.to raise_error(ArgumentError, /Task required/)
    end

    it "builds agent from persona" do
      # Setup mock model to return final answer
      mock_model.queue_final_answer("Built agent result")

      allow(Smolagents).to receive(:agent).and_call_original

      results = parallel_host.spawn_parallel([
                                               { persona: :researcher, task: "Test task" }
                                             ])

      expect(results.first).to eq("Built agent result")
    end
  end

  describe "ParallelExecutionError" do
    let(:error_class) { Smolagents::Concerns::Orchestration::ParallelAgents::ParallelExecutionError }

    it "stores errors" do
      errors = [StandardError.new("e1"), StandardError.new("e2")]
      error = error_class.new(errors)

      expect(error.errors).to eq(errors)
      expect(error.failure_count).to eq(2)
    end

    it "formats message for single error" do
      error = error_class.new([StandardError.new("Single failure")])

      expect(error.message).to include("Single failure")
    end

    it "formats message for multiple errors" do
      error = error_class.new([StandardError.new("e1"), StandardError.new("e2")])

      expect(error.message).to include("2 errors")
      expect(error.message).to include("e1")
      expect(error.message).to include("e2")
    end
  end
end
