RSpec.describe Smolagents::Agents::ToolCalling do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    to_tool_calling_prompt: "test_tool: does something")
  end

  describe "class structure" do
    it "inherits from Agent" do
      expect(described_class.superclass).to eq(Smolagents::Agents::Agent)
    end

    it "includes ToolExecution concern" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::ToolExecution)
    end
  end

  describe "#initialize" do
    it "sets default max_tool_threads" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])
      expect(agent.max_tool_threads).to eq(4)
    end

    it "accepts custom max_tool_threads" do
      agent = described_class.new(model: mock_model, tools: [mock_tool], max_tool_threads: 8)
      expect(agent.max_tool_threads).to eq(8)
    end
  end

  describe "#system_prompt" do
    it "generates a prompt string" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])
      expect(agent.system_prompt).to be_a(String)
    end
  end
end
