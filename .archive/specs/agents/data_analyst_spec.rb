RSpec.describe Smolagents::Agents::DataAnalyst do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  describe "class structure" do
    it "inherits from Code" do
      expect(described_class.superclass).to eq(Smolagents::Agents::Code)
    end
  end

  describe "#initialize" do
    it "sets up data analysis tools" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::RubyInterpreterTool)
      expect(tool_classes).to include(Smolagents::DuckDuckGoSearchTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end
  end

  describe "#system_prompt" do
    it "includes data analysis instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("data")
    end
  end
end
