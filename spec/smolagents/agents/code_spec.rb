# frozen_string_literal: true

RSpec.describe Smolagents::Agents::Code do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    to_code_prompt: "def test_tool; end")
  end

  describe "class structure" do
    it "inherits from Agent" do
      expect(described_class.superclass).to eq(Smolagents::Agents::Agent)
    end

    it "includes CodeExecution concern" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::CodeExecution)
    end
  end

  describe "#initialize" do
    it "sets up executor" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])
      expect(agent.executor).to be_a(Smolagents::LocalRubyExecutor)
    end

    it "accepts custom executor" do
      custom_executor = instance_double(Smolagents::LocalRubyExecutor)
      allow(custom_executor).to receive(:send_tools)
      agent = described_class.new(model: mock_model, tools: [mock_tool], executor: custom_executor)
      expect(agent.executor).to eq(custom_executor)
    end
  end

  describe "#system_prompt" do
    it "generates a prompt string" do
      agent = described_class.new(model: mock_model, tools: [mock_tool])
      expect(agent.system_prompt).to be_a(String)
      expect(agent.system_prompt).to include("Ruby")
    end
  end
end
