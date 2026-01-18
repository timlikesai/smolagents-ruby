RSpec.describe Smolagents::Concerns::ReActLoop::Repetition::Guidance do
  let(:instance) do
    Class.new { include Smolagents::Concerns::ReActLoop::Repetition::Guidance }.new
  end

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(:generate_tool_guidance, :generate_code_guidance, :generate_observation_guidance)
    end
  end

  describe "TEMPLATES" do
    it "defines templates for all repetition types" do
      expect(described_class::TEMPLATES).to include(:tool_call, :code_action, :observation)
    end
  end

  describe "#generate_tool_guidance" do
    it "includes the tool name" do
      guidance = instance.send(:generate_tool_guidance, "search", 3)
      expect(guidance).to include("search")
    end

    it "includes the repetition count" do
      guidance = instance.send(:generate_tool_guidance, "search", 5)
      expect(guidance).to include("5 times")
    end

    it "suggests a different approach" do
      guidance = instance.send(:generate_tool_guidance, "search", 3)
      expect(guidance).to include("different approach")
    end
  end

  describe "#generate_code_guidance" do
    it "includes the repetition count" do
      guidance = instance.send(:generate_code_guidance, 4)
      expect(guidance).to include("4 times")
    end

    it "mentions same code" do
      guidance = instance.send(:generate_code_guidance, 3)
      expect(guidance).to include("same code")
    end

    it "suggests a different approach" do
      guidance = instance.send(:generate_code_guidance, 3)
      expect(guidance).to include("different approach")
    end
  end

  describe "#generate_observation_guidance" do
    it "includes the repetition count" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("3 times")
    end

    it "mentions same result" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("same result")
    end

    it "suggests different tool or inputs" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("different tool or inputs")
    end
  end
end
