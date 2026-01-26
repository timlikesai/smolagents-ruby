RSpec.describe Smolagents::ToolResult do
  describe "Creation module" do
    describe ".empty" do
      it "creates an empty result" do
        result = described_class.empty(tool_name: "test")

        expect(result).to be_a(described_class)
        expect(result.data).to eq([])
        expect(result.tool_name).to eq("test")
      end

      it "defaults to 'unknown' tool_name" do
        result = described_class.empty

        expect(result.tool_name).to eq("unknown")
      end
    end

    describe ".error" do
      it "creates an error result from exception" do
        error = StandardError.new("Something went wrong")
        result = described_class.error(error, tool_name: "test")

        expect(result).to be_a(described_class)
        expect(result.metadata[:error]).to include("StandardError")
        expect(result.metadata[:error]).to include("Something went wrong")
        expect(result.metadata[:success]).to be false
      end

      it "creates an error result from string" do
        result = described_class.error("Error message", tool_name: "test")

        expect(result.metadata[:error]).to eq("Error message")
        expect(result.metadata[:success]).to be false
      end

      it "preserves additional metadata" do
        result = described_class.error(
          "Failed",
          tool_name: "test",
          metadata: { step: 1 }
        )

        expect(result.metadata[:step]).to eq(1)
        expect(result.metadata[:error]).to eq("Failed")
      end
    end

    describe "#+" do
      it "concatenates two array results" do
        result1 = described_class.new([1, 2], tool_name: "a")
        result2 = described_class.new([3, 4], tool_name: "b")

        combined = result1 + result2

        expect(combined.data).to eq([1, 2, 3, 4])
      end

      it "combines tool names" do
        result1 = described_class.new([1], tool_name: "a")
        result2 = described_class.new([2], tool_name: "b")

        combined = result1 + result2

        expect(combined.tool_name).to eq("a+b")
      end

      it "tracks source tool names in metadata" do
        result1 = described_class.new([1], tool_name: "tool1")
        result2 = described_class.new([2], tool_name: "tool2")

        combined = result1 + result2

        expect(combined.metadata[:combined_from]).to eq(%w[tool1 tool2])
      end
    end
  end
end
