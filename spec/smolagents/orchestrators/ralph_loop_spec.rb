require "spec_helper"

RSpec.describe Smolagents::Orchestrators::RalphLoop, :slow do
  let(:mock_model) do
    Smolagents::Testing::MockModel.new.tap do |m|
      m.queue_code_action('final_answer(answer: "Done with iteration")')
    end
  end

  let(:agent) do
    Smolagents.agent
              .model { mock_model }
              .build
  end

  describe "#run" do
    it "runs iterations until max_iterations", max_time: 0.3 do
      # Queue enough responses for 3 iterations
      3.times { mock_model.queue_code_action('final_answer(answer: "Working...")') }

      loop_runner = described_class.new(
        agent:,
        prompt: "Build something",
        max_iterations: 3
      )

      result = loop_runner.run

      expect(result).to be_a(Smolagents::Orchestrators::LoopResult)
      expect(result.iteration_count).to eq(3)
    end

    it "stops early when completion is detected", max_time: 0.2 do
      mock_model.queue_code_action('final_answer(answer: "Task complete!")')

      loop_runner = described_class.new(
        agent:,
        prompt: "Build something",
        max_iterations: 10,
        completion_promise: "complete"
      )

      result = loop_runner.run

      expect(result.iteration_count).to eq(1)
      expect(result.completed).to be true
    end

    it "tracks iteration history", max_time: 0.2 do
      2.times { mock_model.queue_code_action('final_answer(answer: "Step done")') }

      loop_runner = described_class.new(
        agent:,
        prompt: "Build something",
        max_iterations: 2
      )

      result = loop_runner.run

      expect(result.iterations.size).to eq(2)
      expect(result.iterations.first.iteration).to eq(1)
      expect(result.iterations.last.iteration).to eq(2)
    end

    it "injects iteration context into prompts", max_time: 0.2 do
      prompts_received = []
      allow(agent).to receive(:run) do |prompt|
        prompts_received << prompt
        Smolagents::Types::RunResult.new(output: "Done", steps: [], context: nil)
      end

      loop_runner = described_class.new(
        agent:,
        prompt: "Build a REST API",
        max_iterations: 1,
        completion_promise: "Tests passing"
      )

      loop_runner.run

      expect(prompts_received.first).to include("Build a REST API")
      expect(prompts_received.first).to include("Iteration: 1")
      expect(prompts_received.first).to include("Complete when: Tests passing")
      expect(prompts_received.first).to include("Build on what exists")
    end
  end

  describe "IterationResult" do
    let(:result) do
      Smolagents::Orchestrators::IterationResult.new(
        iteration: 1,
        output: "test output",
        steps: 5,
        duration: 1.5
      )
    end

    it "reports success when no error" do
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "reports failure when error present" do
      error_result = Smolagents::Orchestrators::IterationResult.new(
        iteration: 1,
        output: nil,
        steps: 0,
        duration: 0.1,
        error: "Something went wrong"
      )

      expect(error_result.success?).to be false
      expect(error_result.failure?).to be true
    end
  end

  describe "LoopResult" do
    let(:iterations) do
      [
        Smolagents::Orchestrators::IterationResult.new(iteration: 1, output: "a", steps: 3, duration: 1.0),
        Smolagents::Orchestrators::IterationResult.new(iteration: 2, output: "b", steps: 2, duration: 0.5),
        Smolagents::Orchestrators::IterationResult.new(iteration: 3, output: nil, steps: 0, duration: 0.1,
                                                       error: "failed")
      ]
    end

    let(:result) do
      Smolagents::Orchestrators::LoopResult.new(
        iterations:,
        duration: 1.6,
        completed: false,
        final_output: nil
      )
    end

    it "counts iterations" do
      expect(result.iteration_count).to eq(3)
    end

    it "counts successes and failures" do
      expect(result.success_count).to eq(2)
      expect(result.failure_count).to eq(1)
    end

    it "sums total steps" do
      expect(result.total_steps).to eq(5)
    end
  end

  describe "DSL entry point" do
    it "provides Smolagents.ralph_loop", max_time: 0.2 do
      mock_model.queue_code_action('final_answer(answer: "complete")')

      result = Smolagents.ralph_loop(
        agent:,
        prompt: "Test task",
        max_iterations: 1,
        completion_promise: "complete"
      )

      expect(result).to be_a(Smolagents::Orchestrators::LoopResult)
    end
  end
end
