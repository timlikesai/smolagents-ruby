require "spec_helper"

RSpec.describe Smolagents::Agents::Agent::Execution do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:agent) { Smolagents::Agents::Agent.new(model: mock_model, tools: []) }
  let(:mock_executor) do
    instance_double(Smolagents::RactorExecutor).tap do |e|
      allow(e).to receive(:send_tools)
      allow(e).to receive(:send_variables)
      allow(e).to receive(:tool_calls).and_return([])
      allow(e).to receive(:respond_to?).with(:tool_calls).and_return(true)
    end
  end

  before do
    allow(Smolagents::RactorExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "#run" do
    before do
      mock_model.queue_code_action('final_answer(answer: "done")')
      allow(mock_executor).to receive(:execute).and_return(
        Smolagents::Executors::ExecutionResult.success(output: "done", final_answer: true)
      )
    end

    it "delegates to runtime" do
      result = agent.run("test task")

      expect(result).to be_a(Smolagents::Types::RunResult)
    end

    it "accepts stream option" do
      enumerator = agent.run("test task", stream: true)

      expect(enumerator).to respond_to(:each)
    end

    it "accepts reset option" do
      # Run once to build memory
      agent.run("first task")

      # Run again without reset
      mock_model.queue_code_action('final_answer(answer: "second")')
      agent.run("second task", reset: false)

      # Memory should have steps from both runs
      expect(agent.memory.steps.size).to be >= 2
    end

    it "accepts images option" do
      # Should not raise when images are provided
      expect { agent.run("describe image", images: ["/path/to/image.png"]) }.not_to raise_error
    end

    it "accepts additional_prompting option" do
      expect { agent.run("task", additional_prompting: "Extra instructions") }.not_to raise_error
    end
  end

  describe "#run_fiber" do
    before do
      mock_model.queue_code_action('final_answer(answer: "fiber done")')
      allow(mock_executor).to receive(:execute).and_return(
        Smolagents::Executors::ExecutionResult.success(output: "fiber done", final_answer: true)
      )
    end

    it "returns a Fiber" do
      fiber = agent.run_fiber("test task")

      expect(fiber).to be_a(Fiber)
    end

    it "yields control at each step" do
      fiber = agent.run_fiber("test task")
      first_yield = fiber.resume

      # First yield should be an ActionStep or RunResult
      expect(first_yield).to(satisfy do |v|
        v.is_a?(Smolagents::Types::ActionStep) ||
          v.is_a?(Smolagents::Types::RunResult) ||
          v.is_a?(Smolagents::Events::ControlYielded)
      end)
    end

    it "accepts reset option" do
      fiber = agent.run_fiber("task", reset: true)

      expect(fiber).to be_a(Fiber)
    end

    it "accepts images option" do
      fiber = agent.run_fiber("task", images: ["/image.png"])

      expect(fiber).to be_a(Fiber)
    end

    it "accepts additional_prompting option" do
      fiber = agent.run_fiber("task", additional_prompting: "Be concise")

      expect(fiber).to be_a(Fiber)
    end
  end

  describe "#step" do
    before do
      mock_model.queue_code_action('result = "step output"')
      allow(mock_executor).to receive(:execute).and_return(
        Smolagents::Executors::ExecutionResult.success(output: "step output")
      )
    end

    it "executes a single step" do
      # First need to add a task to memory
      agent.memory.add_task("test task")

      step_result = agent.step("test task", step_number: 0)

      expect(step_result).to be_a(Smolagents::Types::ActionStep)
    end

    it "accepts step_number parameter" do
      agent.memory.add_task("test task")

      step_result = agent.step("test task", step_number: 5)

      expect(step_result.step_number).to eq(5)
    end

    it "returns action step with timing" do
      agent.memory.add_task("test task")

      step_result = agent.step("test task", step_number: 0)

      expect(step_result.timing).not_to be_nil
      expect(step_result.timing.start_time).not_to be_nil
      expect(step_result.timing.end_time).not_to be_nil
    end
  end
end
