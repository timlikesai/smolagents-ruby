require "spec_helper"

RSpec.describe Smolagents::Agents::AgentRuntime::StepExecution do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_executor) do
    instance_double(Smolagents::RactorExecutor).tap do |e|
      allow(e).to receive(:send_tools)
      allow(e).to receive(:send_variables)
      allow(e).to receive_messages(execute: Smolagents::Executors::ExecutionResult.success(output: "step result"),
                                   tool_calls: [])
      allow(e).to receive(:respond_to?).with(:tool_calls).and_return(true)
    end
  end
  let(:tools) { { "final_answer" => Smolagents::FinalAnswerTool.new } }
  let(:memory) { Smolagents::Runtime::AgentMemory.new("System prompt") }
  let(:logger) { Smolagents::Logging::NullLogger.instance }

  let(:runtime) do
    Smolagents::Agents::AgentRuntime.new(
      model: mock_model,
      tools:,
      executor: mock_executor,
      memory:,
      max_steps: 10,
      logger:
    )
  end

  before do
    mock_model.queue_code_action('result = "step output"')
    memory.add_task("test task")
  end

  describe "#step" do
    it "returns an ActionStep" do
      step_result = runtime.step("test task", step_number: 0)

      expect(step_result).to be_a(Smolagents::Types::ActionStep)
    end

    it "uses the provided step_number" do
      step_result = runtime.step("test task", step_number: 5)

      expect(step_result.step_number).to eq(5)
    end

    it "records timing information" do
      step_result = runtime.step("test task", step_number: 0)

      expect(step_result.timing).not_to be_nil
      expect(step_result.timing.start_time).not_to be_nil
      expect(step_result.timing.end_time).not_to be_nil
    end

    it "executes code in the step" do
      runtime.step("test task", step_number: 0)

      expect(mock_executor).to have_received(:execute)
    end

    it "ignores the task parameter (used for context only)" do
      # Task is passed for context but the step uses memory
      step1 = runtime.step("task A", step_number: 0)
      mock_model.queue_code_action('result = "another output"')
      step2 = runtime.step("task B", step_number: 1)

      # Both should execute successfully
      expect(step1).to be_a(Smolagents::Types::ActionStep)
      expect(step2).to be_a(Smolagents::Types::ActionStep)
    end
  end

  describe "step timing integration" do
    it "wraps step execution with timing" do
      start_before = Time.now
      step_result = runtime.step("test task", step_number: 0)
      end_after = Time.now

      expect(step_result.timing.start_time).to be >= start_before
      expect(step_result.timing.end_time).to be <= end_after
    end

    it "calculates step duration correctly" do
      step_result = runtime.step("test task", step_number: 0)

      expect(step_result.timing.start_time).to be_a(Float)
      expect(step_result.timing.end_time).to be_a(Float)
      expect(step_result.timing.start_time).to be <= step_result.timing.end_time
    end
  end

  describe "action step contents" do
    it "includes model output message" do
      step_result = runtime.step("test task", step_number: 0)

      # model_output_message contains the message from the model
      expect(step_result.model_output_message).not_to be_nil
    end

    it "includes observations" do
      step_result = runtime.step("test task", step_number: 0)

      # Observations may be nil or a string
      expect(step_result.observations).to(satisfy { |v| v.nil? || v.is_a?(String) })
    end
  end

  describe "error handling" do
    context "when code execution fails" do
      before do
        allow(mock_executor).to receive(:execute).and_return(
          Smolagents::Executors::ExecutionResult.failure(error: "RuntimeError: Something went wrong")
        )
      end

      it "still returns an ActionStep" do
        step_result = runtime.step("test task", step_number: 0)

        expect(step_result).to be_a(Smolagents::Types::ActionStep)
      end

      it "includes error in observations" do
        step_result = runtime.step("test task", step_number: 0)

        expect(step_result.error).not_to be_nil
      end
    end
  end

  describe "multiple steps" do
    before do
      mock_model.queue_code_action('first = "result 1"')
      mock_model.queue_code_action('second = "result 2"')
      mock_model.queue_code_action('third = "result 3"')
    end

    it "increments step numbers correctly" do
      step0 = runtime.step("task", step_number: 0)
      step1 = runtime.step("task", step_number: 1)
      step2 = runtime.step("task", step_number: 2)

      expect(step0.step_number).to eq(0)
      expect(step1.step_number).to eq(1)
      expect(step2.step_number).to eq(2)
    end

    it "maintains separate timing for each step" do
      step0 = runtime.step("task", step_number: 0)
      step1 = runtime.step("task", step_number: 1)

      # Second step should start after first step ends
      expect(step1.timing.start_time).to be >= step0.timing.end_time
    end
  end
end
