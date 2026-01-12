RSpec.describe Smolagents::Agents::Assistant do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  describe "class structure" do
    it "inherits from ToolCalling" do
      expect(described_class.superclass).to eq(Smolagents::Agents::ToolCalling)
    end
  end

  describe "#initialize" do
    it "sets up assistant tools" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::UserInputTool)
      expect(tool_classes).to include(Smolagents::DuckDuckGoSearchTool)
      expect(tool_classes).to include(Smolagents::VisitWebpageTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end
  end

  describe "#system_prompt" do
    it "includes interactive assistant instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("interactive")
    end
  end
end
