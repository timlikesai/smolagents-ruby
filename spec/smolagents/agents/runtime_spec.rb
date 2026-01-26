require "spec_helper"

RSpec.describe Smolagents::Agents::AgentRuntime do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_executor) do
    instance_double(Smolagents::RactorExecutor).tap do |e|
      allow(e).to receive(:send_tools)
      allow(e).to receive(:send_variables)
      allow(e).to receive_messages(execute: Smolagents::Executors::ExecutionResult.success(output: "result"),
                                   tool_calls: [])
      allow(e).to receive(:respond_to?).with(:tool_calls).and_return(true)
    end
  end
  let(:tools) { { "final_answer" => Smolagents::FinalAnswerTool.new } }
  let(:memory) { Smolagents::Runtime::AgentMemory.new("System prompt") }
  let(:logger) { Smolagents::Logging::NullLogger.instance }

  let(:runtime) do
    described_class.new(
      model: mock_model,
      tools:,
      executor: mock_executor,
      memory:,
      max_steps: 10,
      logger:
    )
  end

  describe "initialization" do
    it "creates a runtime with required parameters" do
      expect(runtime).to be_a(described_class)
    end

    it "sets model" do
      expect(runtime.instance_variable_get(:@model)).to eq(mock_model)
    end

    it "sets tools" do
      expect(runtime.instance_variable_get(:@tools)).to eq(tools)
    end

    it "sets executor" do
      expect(runtime.executor).to eq(mock_executor)
    end

    it "sets memory" do
      expect(runtime.instance_variable_get(:@memory)).to eq(memory)
    end

    it "sets max_steps" do
      expect(runtime.instance_variable_get(:@max_steps)).to eq(10)
    end

    it "sets logger" do
      expect(runtime.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe "optional parameters" do
    it "accepts custom_instructions" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        custom_instructions: "Be helpful"
      )

      expect(runtime.instance_variable_get(:@custom_instructions)).to eq("Be helpful")
    end

    it "accepts planning_interval" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        planning_interval: 5
      )

      expect(runtime.planning_interval).to eq(5)
    end

    it "accepts spawn_config" do
      spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 3)
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        spawn_config:
      )

      expect(runtime.instance_variable_get(:@spawn_config)).to eq(spawn_config)
    end

    it "accepts evaluation_enabled" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        evaluation_enabled: true
      )

      expect(runtime.instance_variable_get(:@evaluation_enabled)).to be true
    end

    it "accepts authorized_imports" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        authorized_imports: %w[json yaml]
      )

      expect(runtime.authorized_imports).to eq(%w[json yaml])
    end

    it "accepts sync_events" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        sync_events: true
      )

      expect(runtime.sync_events).to be true
    end

    it "accepts observe_mode" do
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        observe_mode: :structure_only
      )

      expect(runtime.instance_variable_get(:@observe_mode)).to eq(:structure_only)
    end

    it "accepts summarizer_model" do
      summarizer = Smolagents::Testing::MockModel.new
      runtime = described_class.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        summarizer_model: summarizer
      )

      expect(runtime.instance_variable_get(:@summarizer_model)).to eq(summarizer)
    end
  end

  describe "included modules" do
    it "includes Monitorable" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::Monitorable)
    end

    it "includes ReActLoop" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
    end

    it "includes Planning" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::Planning)
    end

    it "includes StepExecution" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::StepExecution)
    end

    it "includes CodeExecution" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::CodeExecution)
    end

    it "includes Evaluation" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::Evaluation)
    end

    it "includes GoalTracking" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::GoalTracking)
    end

    it "includes WorkingMemory" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::WorkingMemory)
    end

    it "includes ContextOrchestration" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::ContextOrchestration)
    end
  end

  describe "#run" do
    before do
      mock_model.queue_code_action('final_answer(answer: "done")')
      allow(mock_executor).to receive(:execute).and_return(
        Smolagents::Executors::ExecutionResult.success(output: "done", final_answer: true)
      )
    end

    it "executes the task and returns RunResult" do
      result = runtime.run("test task")

      expect(result).to be_a(Smolagents::Types::RunResult)
    end

    it "returns successful result" do
      result = runtime.run("test task")

      expect(result.success?).to be true
    end
  end

  describe "#run_fiber" do
    before do
      mock_model.queue_code_action('final_answer(answer: "fiber result")')
      allow(mock_executor).to receive(:execute).and_return(
        Smolagents::Executors::ExecutionResult.success(output: "fiber result", final_answer: true)
      )
    end

    it "returns a Fiber" do
      fiber = runtime.run_fiber("test task")

      expect(fiber).to be_a(Fiber)
    end
  end

  describe "#step" do
    before do
      mock_model.queue_code_action('result = "step output"')
      memory.add_task("test task")
    end

    it "executes a single step" do
      step_result = runtime.step("test task", step_number: 0)

      expect(step_result).to be_a(Smolagents::Types::ActionStep)
    end
  end
end
