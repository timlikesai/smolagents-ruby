RSpec.describe Smolagents::Agents::Researcher do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  describe "class structure" do
    it "inherits from ToolCalling" do
      expect(described_class.superclass).to eq(Smolagents::Agents::ToolCalling)
    end
  end

  describe "#initialize" do
    it "sets up default research tools" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::DuckDuckGoSearchTool)
      expect(tool_classes).to include(Smolagents::VisitWebpageTool)
      expect(tool_classes).to include(Smolagents::WikipediaSearchTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end
  end

  describe "#system_prompt" do
    it "includes research-specific instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("research")
    end
  end
end
