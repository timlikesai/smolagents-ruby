require "spec_helper"

RSpec.describe Smolagents::Agents::AgentRuntime::Accessors do
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
    Smolagents::Agents::AgentRuntime.new(
      model: mock_model,
      tools:,
      executor: mock_executor,
      memory:,
      max_steps: 10,
      logger:,
      authorized_imports: %w[json yaml]
    )
  end

  describe "#executor" do
    it "returns the code executor" do
      expect(runtime.executor).to eq(mock_executor)
    end
  end

  describe "#authorized_imports" do
    it "returns the list of authorized imports" do
      expect(runtime.authorized_imports).to eq(%w[json yaml])
    end
  end

  describe "#sync_events" do
    context "when sync_events is false (default)" do
      it "returns false" do
        expect(runtime.sync_events).to be false
      end
    end

    context "when sync_events is true" do
      let(:runtime_with_sync) do
        Smolagents::Agents::AgentRuntime.new(
          model: mock_model,
          tools:,
          executor: mock_executor,
          memory:,
          max_steps: 10,
          logger:,
          sync_events: true
        )
      end

      it "returns true" do
        expect(runtime_with_sync.sync_events).to be true
      end
    end
  end

  describe "#emit" do
    let(:test_event) { Smolagents::Events::StepCompleted.create(step_number: 0, outcome: :success, observations: nil) }

    context "when sync_events is false" do
      it "emits events asynchronously (default behavior)" do
        # Without a queue, events go nowhere, but shouldn't raise
        expect { runtime.emit(test_event) }.not_to raise_error
      end
    end

    context "when sync_events is true" do
      let(:runtime_with_sync) do
        Smolagents::Agents::AgentRuntime.new(
          model: mock_model,
          tools:,
          executor: mock_executor,
          memory:,
          max_steps: 10,
          logger:,
          sync_events: true
        )
      end

      it "emits events synchronously" do
        handler_called = false
        runtime_with_sync.on(Smolagents::Events::StepCompleted) { handler_called = true }

        runtime_with_sync.emit(test_event)

        expect(handler_called).to be true
      end
    end
  end

  describe "#write_memory_to_messages" do
    before do
      memory.add_task("test task")
    end

    it "returns an array of messages" do
      messages = runtime.write_memory_to_messages

      expect(messages).to be_an(Array)
    end

    it "accepts summary_mode parameter" do
      messages = runtime.write_memory_to_messages(summary_mode: true)

      expect(messages).to be_an(Array)
    end

    it "includes system message" do
      messages = runtime.write_memory_to_messages

      system_messages = messages.select do |m|
        role = m.respond_to?(:role) ? m.role : m[:role]
        [:system, "system"].include?(role)
      rescue StandardError
        false
      end
      expect(system_messages).not_to be_empty
    end

    it "includes task message" do
      messages = runtime.write_memory_to_messages

      expect(messages.any? do |m|
        content = m.respond_to?(:content) ? m.content : m[:content]
        content.to_s.include?("test task")
      end).to be true
    end
  end
end
