RSpec.describe Smolagents::Utilities::Prompts::Agent do
  let(:tool) { build_test_tool(name: "search") }

  describe "code mode (default)" do
    it "includes Ruby 4.0 identity" do
      prompt = described_class.generate(tools: [tool])

      expect(prompt).to include("Ruby 4.0 agent")
      expect(prompt).to include("```ruby")
    end
  end

  describe "native mode" do
    it "uses native tool calling intro" do
      prompt = described_class.generate(
        tools: [tool], tool_calling_mode: :native
      )

      expect(prompt).to include("using the provided tools")
      expect(prompt).to include("function calling API")
    end

    it "does not include Ruby code instructions" do
      prompt = described_class.generate(
        tools: [tool], tool_calling_mode: :native
      )

      expect(prompt).not_to include("Ruby 4.0 agent")
      expect(prompt).not_to include("```ruby")
    end

    it "omits code example section" do
      prompt = described_class.generate(
        tools: [tool], tool_calling_mode: :native
      )

      expect(prompt).not_to include("EXAMPLE:")
      expect(prompt).not_to include("Compare Ruby and Python")
    end

    it "omits debug helpers" do
      prompt = described_class.generate(
        tools: [tool], tool_calling_mode: :native
      )

      expect(prompt).not_to include("DEBUG HELPERS")
      expect(prompt).not_to include("inspect_state")
    end

    it "still includes tool descriptions" do
      prompt = described_class.generate(
        tools: [tool], tool_calling_mode: :native
      )

      expect(prompt).to include("AVAILABLE METHODS")
      expect(prompt).to include("search")
    end
  end
end
