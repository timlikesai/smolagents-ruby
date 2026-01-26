RSpec.describe Smolagents::Testing::Helpers do
  describe "module inclusion" do
    it "includes ModelHelpers" do
      expect(described_class).to include(Smolagents::Testing::Helpers::ModelHelpers)
    end

    it "includes AgentHelpers" do
      expect(described_class).to include(Smolagents::Testing::Helpers::AgentHelpers)
    end

    it "includes ToolHelpers" do
      expect(described_class).to include(Smolagents::Testing::Helpers::ToolHelpers)
    end
  end

  describe "Fixtures constant" do
    it "is available as Testing::Fixtures" do
      expect(Smolagents::Testing::Fixtures).to eq(Smolagents::Testing::Helpers::Fixtures)
    end

    it "provides fixture creation methods" do
      expect(Smolagents::Testing::Fixtures).to respond_to(:chat_message)
      expect(Smolagents::Testing::Fixtures).to respond_to(:action_step)
      expect(Smolagents::Testing::Fixtures).to respond_to(:tool_call)
      expect(Smolagents::Testing::Fixtures).to respond_to(:token_usage)
    end
  end
end
