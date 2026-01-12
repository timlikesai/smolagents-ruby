# frozen_string_literal: true

RSpec.describe Smolagents::Agents::Transcriber do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return("test-api-key")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test-api-key")
  end

  describe "class structure" do
    it "inherits from Code" do
      expect(described_class.superclass).to eq(Smolagents::Agents::Code)
    end
  end

  describe "#initialize" do
    it "sets up transcription tools" do
      agent = described_class.new(model: mock_model)
      tool_classes = agent.tools.values.map(&:class)

      expect(tool_classes).to include(Smolagents::SpeechToTextTool)
      expect(tool_classes).to include(Smolagents::RubyInterpreterTool)
      expect(tool_classes).to include(Smolagents::FinalAnswerTool)
    end

    it "accepts provider option" do
      expect { described_class.new(model: mock_model, provider: "openai") }.not_to raise_error
    end
  end

  describe "#system_prompt" do
    it "includes transcription-specific instructions" do
      agent = described_class.new(model: mock_model)
      expect(agent.system_prompt).to include("transcri")
    end
  end
end
