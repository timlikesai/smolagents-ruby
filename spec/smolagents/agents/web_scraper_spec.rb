RSpec.describe Smolagents::Agents::WebScraper do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  describe "class structure" do
    it "inherits from Code" do
      expect(described_class.superclass).to eq(Smolagents::Agents::Code)
    end
  end

  describe "#initialize" do
    it "sets up web scraping tools" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::DuckDuckGoSearchTool)
      expect(tool_classes).to include(Smolagents::VisitWebpageTool)
      expect(tool_classes).to include(Smolagents::RubyInterpreterTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end
  end

  describe "#system_prompt" do
    it "includes extraction instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("extract")
    end
  end
end
