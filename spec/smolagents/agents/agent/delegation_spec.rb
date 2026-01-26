require "spec_helper"

RSpec.describe Smolagents::Agents::Agent::Delegation do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:agent) { Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool]) }
  let(:mock_executor) { instance_double(Smolagents::RactorExecutor) }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    format_for: "def test_tool(value:)\n  # A test tool\nend",
                    inputs: { "value" => { "type" => "string", "description" => "Test input" } },
                    description: "A test tool")
  end

  before do
    allow(mock_executor).to receive(:send_tools)
    allow(Smolagents::RactorExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "#on" do
    it "returns self for chaining" do
      result = agent.on(:step_complete) { |event| event } # no-op handler

      expect(result).to eq(agent)
    end

    it "registers handler on the agent" do
      called = false
      agent.on(Smolagents::Events::StepCompleted) { called = true }

      # Consume event directly to test registration
      event = Smolagents::Events::StepCompleted.create(step_number: 0, outcome: :success, observations: nil)
      agent.consume(event)

      expect(called).to be true
    end
  end

  describe "#state" do
    it "returns the runtime internal state hash" do
      expect(agent.state).to be_a(Hash)
    end

    it "returns a mutable state" do
      agent.state[:test_key] = "test_value"

      expect(agent.state[:test_key]).to eq("test_value")
    end
  end

  describe "#planning_interval" do
    context "when planning is not configured" do
      it "returns nil" do
        expect(agent.planning_interval).to be_nil
      end
    end

    context "when planning is configured" do
      let(:planning) { Smolagents::Types::PlanningConfig.create(interval: 5) }
      let(:config) { Smolagents::Types::AgentConfig.create(planning:) }
      let(:agent_with_planning) do
        Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)
      end

      it "returns the planning interval" do
        expect(agent_with_planning.planning_interval).to eq(5)
      end
    end
  end

  describe "#planning_templates" do
    context "when no custom templates" do
      it "returns default templates" do
        templates = agent.planning_templates

        expect(templates).to be_a(Hash)
      end
    end

    context "with custom templates" do
      let(:custom_templates) { { initial_plan: "Custom: %<task>s" } }
      let(:planning) { Smolagents::Types::PlanningConfig.create(templates: custom_templates) }
      let(:config) { Smolagents::Types::AgentConfig.create(planning:) }
      let(:agent_with_templates) do
        Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool], config:)
      end

      it "returns the custom templates" do
        expect(agent_with_templates.planning_templates[:initial_plan]).to eq("Custom: %<task>s")
      end
    end
  end
end
