require "spec_helper"

RSpec.describe Smolagents::Testing::ModelCapabilities::Formatters do
  describe ".header_line" do
    it "returns formatted header row with all columns" do
      header = described_class.header_line

      expect(header).to include("Model")
      expect(header).to include("Size")
      expect(header).to include("Context")
      expect(header).to include("Reason")
      expect(header).to include("V")
      expect(header).to include("T")
      expect(header).to include("Architecture")
    end

    it "uses pipe separators between columns" do
      header = described_class.header_line

      expect(header).to include(" | ")
    end

    it "applies consistent column widths" do
      header = described_class.header_line

      # Model column is 30 chars wide
      expect(header).to match(/^Model\s{25}/)
    end
  end

  describe Smolagents::Testing::ModelCapabilities::Formatters::InstanceMethods do
    let(:capability) do
      Smolagents::Testing::ModelCapabilities::Capability.new(
        model_id: "test-model-7b",
        context_length: 8192,
        vision: true,
        tool_use: true,
        reasoning: :strong,
        speed: :fast,
        size_category: :medium,
        specialization: :general,
        provider: :lm_studio,
        quantization: :int8,
        architecture: :transformer
      )
    end

    describe "#size_str" do
      it "returns the size_category as a string" do
        expect(capability.size_str).to eq("medium")
      end

      it "works for all size categories" do
        tiny_cap = capability.with(size_category: :tiny)
        small_cap = capability.with(size_category: :small)
        large_cap = capability.with(size_category: :large)

        expect(tiny_cap.size_str).to eq("tiny")
        expect(small_cap.size_str).to eq("small")
        expect(large_cap.size_str).to eq("large")
      end
    end

    describe "#summary_line" do
      it "returns formatted single-line summary" do
        line = capability.summary_line

        expect(line).to include("test-model-7b")
        expect(line).to include("medium")
        expect(line).to include("8192")
        expect(line).to include("strong")
        expect(line).to include("transformer")
      end

      it "shows V indicator when vision is enabled" do
        line = capability.summary_line

        expect(line).to include("V")
      end

      it "shows T indicator when tool_use is enabled" do
        line = capability.summary_line

        expect(line).to include("T")
      end

      it "shows dash when vision is disabled" do
        no_vision = capability.with(vision: false)
        line = no_vision.summary_line

        # Should have dash where V would be
        expect(line).to match(/\| - \|/)
      end

      it "shows dash when tool_use is disabled" do
        no_tools = capability.with(tool_use: false)
        line = no_tools.summary_line

        # Should have dash where T would be
        expect(line).to match(/\| - \|/)
      end

      it "uses pipe separators" do
        line = capability.summary_line

        expect(line).to include(" | ")
      end

      it "aligns with header columns" do
        header = Smolagents::Testing::ModelCapabilities::Formatters.header_line
        summary = capability.summary_line

        # Both should have same number of separators
        header_columns = header.split(" | ").length
        summary_columns = summary.split(" | ").length

        expect(summary_columns).to eq(header_columns)
      end
    end
  end
end
