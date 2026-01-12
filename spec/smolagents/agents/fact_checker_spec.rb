RSpec.describe Smolagents::Agents::FactChecker do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  describe "class structure" do
    it "inherits from ToolCalling" do
      expect(described_class.superclass).to eq(Smolagents::Agents::ToolCalling)
    end
  end

  describe "#initialize" do
    it "sets up fact checking tools with default search provider" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::DuckDuckGoSearchTool)
      expect(tool_classes).to include(Smolagents::WikipediaSearchTool)
      expect(tool_classes).to include(Smolagents::VisitWebpageTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end

    it "accepts brave search provider" do
      agent = described_class.new(model: mock_model, search_provider: :brave)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::BraveSearchTool)
      expect(tool_classes).not_to include(Smolagents::DuckDuckGoSearchTool)
    end

    it "accepts google search provider", skip: "requires SERPAPI_API_KEY" do
      agent = described_class.new(model: mock_model, search_provider: :google)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::GoogleSearchTool)
    end

    it "accepts bing search provider" do
      agent = described_class.new(model: mock_model, search_provider: :bing)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::BingSearchTool)
    end
  end

  describe "#system_prompt" do
    it "includes fact checking instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("fact")
    end
  end
end
