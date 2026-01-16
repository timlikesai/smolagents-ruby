RSpec.describe Smolagents::Agents::Agent do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }
  let(:mock_executor) { instance_double(Smolagents::LocalRubyExecutor) }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    to_code_prompt: "def test_tool; end")
  end

  before do
    allow(mock_executor).to receive(:send_tools)
    allow(Smolagents::LocalRubyExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "initialization" do
    it "creates an agent with model and tools" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])

      expect(agent).to be_a(described_class)
    end

    it "sets up code execution with default executor" do
      allow(Smolagents::LocalRubyExecutor).to receive(:new).and_return(mock_executor)
      allow(mock_executor).to receive(:send_tools)

      described_class.new(model: mock_model, tools: [mock_tool])

      expect(Smolagents::LocalRubyExecutor).to have_received(:new)
      expect(mock_executor).to have_received(:send_tools)
    end

    it "accepts custom executor" do
      custom_executor = instance_double(Smolagents::LocalRubyExecutor)
      allow(custom_executor).to receive(:send_tools)

      agent = described_class.new(model: mock_model, tools: [mock_tool], executor: custom_executor)

      expect(agent.executor).to eq(custom_executor)
    end

    it "accepts authorized_imports" do
      agent = described_class.new(model: mock_model, tools: [mock_tool], authorized_imports: %w[json yaml])

      expect(agent.authorized_imports).to eq(%w[json yaml])
    end
  end

  describe "planning initialization" do
    it "initializes plan_context when created with planning_interval" do
      agent = described_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)

      expect(agent.planning_interval).to eq(3)
      expect(agent.send(:plan_context)).to be_a(Smolagents::PlanContext)
      expect(agent.send(:plan_context)).not_to be_initialized
    end

    it "initializes plan_context even without planning_interval" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])

      expect(agent.planning_interval).to be_nil
      expect(agent.send(:plan_context)).to be_a(Smolagents::PlanContext)
    end

    it "accepts custom planning_templates" do
      custom_templates = { initial_plan: "Custom: %<task>s", planning_system: "Custom" }
      agent = described_class.new(model: mock_model, tools: [mock_tool], planning_templates: custom_templates)

      expect(agent.planning_templates[:initial_plan]).to eq("Custom: %<task>s")
    end
  end

  describe "included modules" do
    it "includes all required concerns" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
      expect(described_class.included_modules).to include(Smolagents::Concerns::StepExecution)
      expect(described_class.included_modules).to include(Smolagents::Concerns::Planning)
      expect(described_class.included_modules).to include(Smolagents::Concerns::ManagedAgents)
      expect(described_class.included_modules).to include(Smolagents::Concerns::CodeExecution)
    end
  end

  describe "#system_prompt" do
    it "generates a prompt with tool descriptions" do
      allow(mock_tool).to receive(:to_code_prompt).and_return("def test_tool; end")

      agent = described_class.new(model: mock_model, tools: [mock_tool])

      expect(agent.system_prompt).to be_a(String)
      expect(agent.system_prompt).not_to be_empty
    end
  end

  describe "factory methods" do
    it "provides .create as primary factory" do
      agent = Smolagents::Agents.create(model: mock_model, tools: [mock_tool])

      expect(agent).to be_a(described_class)
    end

    it "provides .code for backwards compatibility" do
      agent = Smolagents::Agents.code(model: mock_model, tools: [mock_tool])

      expect(agent).to be_a(described_class)
    end
  end
end
