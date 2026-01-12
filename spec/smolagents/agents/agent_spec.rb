RSpec.describe Smolagents::Agents::Agent do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    to_tool_calling_prompt: "test_tool: does something")
  end

  # Create a concrete agent class for testing initialization
  let(:concrete_agent_class) do
    Class.new(described_class) do
      def system_prompt = "Test system prompt"
      def execute_step(_) = nil
    end
  end

  describe "planning initialization" do
    it "initializes plan_context when created with planning_interval" do
      agent = concrete_agent_class.new(model: mock_model, tools: [mock_tool], planning_interval: 3)

      expect(agent.planning_interval).to eq(3)
      expect(agent.send(:plan_context)).to be_a(Smolagents::PlanContext)
      expect(agent.send(:plan_context)).not_to be_initialized
    end

    it "initializes plan_context even without planning_interval" do
      agent = concrete_agent_class.new(model: mock_model, tools: [mock_tool])

      expect(agent.planning_interval).to be_nil
      expect(agent.send(:plan_context)).to be_a(Smolagents::PlanContext)
    end

    it "accepts custom planning_templates" do
      custom_templates = { initial_plan: "Custom: %<task>s", planning_system: "Custom" }
      agent = concrete_agent_class.new(model: mock_model, tools: [mock_tool], planning_templates: custom_templates)

      expect(agent.planning_templates[:initial_plan]).to eq("Custom: %<task>s")
    end
  end

  it "is the base class for all agents" do
    expect(described_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
    expect(described_class.included_modules).to include(Smolagents::Concerns::StepExecution)
    expect(described_class.included_modules).to include(Smolagents::Concerns::Planning)
    expect(described_class.included_modules).to include(Smolagents::Concerns::ManagedAgents)
  end

  it "requires subclasses to implement system_prompt" do
    subclass = Class.new(described_class)
    agent = subclass.allocate
    expect { agent.system_prompt }.to raise_error(NotImplementedError)
  end

  it "requires subclasses to implement execute_step" do
    subclass = Class.new(described_class)
    agent = subclass.allocate
    expect { agent.execute_step(nil) }.to raise_error(NotImplementedError)
  end
end
