require "spec_helper"

RSpec.describe Smolagents::Agents::AgentRuntime::Initialization do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_executor) do
    instance_double(Smolagents::RactorExecutor).tap do |e|
      allow(e).to receive(:send_tools)
      allow(e).to receive(:send_variables)
    end
  end
  let(:tools) { { "final_answer" => Smolagents::FinalAnswerTool.new } }
  let(:memory) { Smolagents::Runtime::AgentMemory.new("System prompt") }
  let(:logger) { Smolagents::Logging::NullLogger.instance }

  describe "CORE_COMPONENTS" do
    it "defines the required core components" do
      expect(described_class::CORE_COMPONENTS).to contain_exactly(
        :model, :tools, :executor, :memory, :max_steps, :logger
      )
    end
  end

  describe "OPTIONAL_COMPONENTS" do
    it "defines optional components with defaults" do
      optional = described_class::OPTIONAL_COMPONENTS

      expect(optional.keys).to include(
        :custom_instructions,
        :spawn_config,
        :authorized_imports,
        :state,
        :sync_events,
        :observe_mode,
        :summarizer_model
      )
    end

    it "has nil default for custom_instructions" do
      expect(described_class::OPTIONAL_COMPONENTS[:custom_instructions]).to be_nil
    end

    it "has nil default for spawn_config" do
      expect(described_class::OPTIONAL_COMPONENTS[:spawn_config]).to be_nil
    end

    it "has empty array default for authorized_imports" do
      expect(described_class::OPTIONAL_COMPONENTS[:authorized_imports]).to eq([])
    end

    it "has hash default for state" do
      expect(described_class::OPTIONAL_COMPONENTS[:state]).to be_a(Hash)
    end

    it "has false default for sync_events" do
      expect(described_class::OPTIONAL_COMPONENTS[:sync_events]).to be false
    end

    it "has :with_summary default for observe_mode" do
      expect(described_class::OPTIONAL_COMPONENTS[:observe_mode]).to eq(:with_summary)
    end

    it "has nil default for summarizer_model" do
      expect(described_class::OPTIONAL_COMPONENTS[:summarizer_model]).to be_nil
    end
  end

  describe "#assign_core (private)" do
    it "assigns all core components" do
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:
      )

      expect(runtime.instance_variable_get(:@model)).to eq(mock_model)
      expect(runtime.instance_variable_get(:@tools)).to eq(tools)
      expect(runtime.executor).to eq(mock_executor)
      expect(runtime.instance_variable_get(:@memory)).to eq(memory)
      expect(runtime.instance_variable_get(:@max_steps)).to eq(10)
      expect(runtime.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe "#assign_optional (private)" do
    context "when optional parameters are provided" do
      it "uses provided values" do
        runtime = Smolagents::Agents::AgentRuntime.new(
          model: mock_model,
          tools:,
          executor: mock_executor,
          memory:,
          max_steps: 10,
          logger:,
          custom_instructions: "Be helpful",
          authorized_imports: %w[json],
          sync_events: true,
          observe_mode: :structure_only
        )

        expect(runtime.instance_variable_get(:@custom_instructions)).to eq("Be helpful")
        expect(runtime.authorized_imports).to eq(%w[json])
        expect(runtime.sync_events).to be true
        expect(runtime.instance_variable_get(:@observe_mode)).to eq(:structure_only)
      end
    end

    context "when optional parameters are not provided" do
      it "uses default values" do
        runtime = Smolagents::Agents::AgentRuntime.new(
          model: mock_model,
          tools:,
          executor: mock_executor,
          memory:,
          max_steps: 10,
          logger:
        )

        expect(runtime.instance_variable_get(:@custom_instructions)).to be_nil
        expect(runtime.authorized_imports).to eq([])
        expect(runtime.sync_events).to be false
        expect(runtime.instance_variable_get(:@observe_mode)).to eq(:with_summary)
      end
    end

    context "when optional parameters are explicitly nil" do
      it "falls back to defaults for nil values" do
        runtime = Smolagents::Agents::AgentRuntime.new(
          model: mock_model,
          tools:,
          executor: mock_executor,
          memory:,
          max_steps: 10,
          logger:,
          authorized_imports: nil,
          sync_events: nil
        )

        # nil should be replaced with default
        expect(runtime.authorized_imports).to eq([])
        expect(runtime.sync_events).to be false
      end
    end
  end

  describe "initialization of concerns" do
    it "initializes planning" do
      runtime = Smolagents::Agents::AgentRuntime.new(
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

    it "initializes goal tracking" do
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:
      )

      # Goal tracking should be initialized
      expect(runtime).to respond_to(:goal_store)
    end

    it "initializes working memory" do
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:
      )

      # Working memory should be initialized
      expect(runtime).to respond_to(:working_memory)
    end

    it "initializes context orchestration" do
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:
      )

      # Context orchestration should be initialized
      expect(runtime).to respond_to(:context_orchestrator)
    end

    it "initializes evaluation" do
      runtime = Smolagents::Agents::AgentRuntime.new(
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

    it "initializes self-refine" do
      refine_config = Smolagents::Types::RefineConfig.default
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:,
        refine_config:
      )

      expect(runtime).to respond_to(:refine_config)
    end

    it "sets up consumer for events" do
      runtime = Smolagents::Agents::AgentRuntime.new(
        model: mock_model,
        tools:,
        executor: mock_executor,
        memory:,
        max_steps: 10,
        logger:
      )

      # Should be able to register event handlers
      expect { runtime.on(:step_complete) { |e| e } }.not_to raise_error
    end
  end
end
