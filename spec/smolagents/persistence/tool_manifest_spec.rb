RSpec.describe Smolagents::Persistence::ToolManifest do
  describe ".from_tool" do
    it "captures registry tool information" do
      tool = Smolagents::FinalAnswerTool.new

      manifest = described_class.from_tool(tool)

      expect(manifest.name).to eq("final_answer")
      expect(manifest.class_name).to eq("Smolagents::Tools::FinalAnswerTool")
      expect(manifest.registry_key).to eq("final_answer")
    end

    it "captures tool with registry key" do
      tool = Smolagents::DuckDuckGoSearchTool.new

      manifest = described_class.from_tool(tool)

      expect(manifest.registry_key).to eq("duckduckgo_search")
      expect(manifest.registry_tool?).to be true
    end

    it "raises error for non-registry tools" do
      custom_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "custom_tool"
        self.description = "A custom tool"
        self.inputs = {}
        self.output_type = "string"

        def execute = "result"
      end.new

      expect { described_class.from_tool(custom_tool) }.to raise_error(
        Smolagents::Persistence::UnserializableToolError,
        /custom_tool.*cannot be serialized/
      )
    end
  end

  describe "#to_h" do
    it "returns serializable hash" do
      manifest = described_class.new(
        name: "final_answer",
        class_name: "Smolagents::FinalAnswerTool",
        registry_key: "final_answer",
        config: {}
      )

      expect(manifest.to_h).to eq({
                                    name: "final_answer",
                                    class_name: "Smolagents::FinalAnswerTool",
                                    registry_key: "final_answer",
                                    config: {}
                                  })
    end
  end

  describe ".from_h" do
    it "reconstructs from hash" do
      hash = {
        name: "duckduckgo_search",
        class_name: "Smolagents::DuckDuckGoSearchTool",
        registry_key: "duckduckgo_search",
        config: {}
      }

      manifest = described_class.from_h(hash)

      expect(manifest.name).to eq("duckduckgo_search")
      expect(manifest.registry_key).to eq("duckduckgo_search")
    end

    it "handles string keys" do
      hash = {
        "name" => "final_answer",
        "class_name" => "Smolagents::FinalAnswerTool",
        "registry_key" => "final_answer",
        "config" => {}
      }

      manifest = described_class.from_h(hash)

      expect(manifest.name).to eq("final_answer")
    end
  end

  describe "#instantiate" do
    it "creates tool from registry" do
      manifest = described_class.new(
        name: "final_answer",
        class_name: "Smolagents::FinalAnswerTool",
        registry_key: "final_answer",
        config: {}
      )

      tool = manifest.instantiate

      expect(tool).to be_a(Smolagents::FinalAnswerTool)
      expect(tool.name).to eq("final_answer")
    end

    it "raises error for unknown registry key" do
      manifest = described_class.new(
        name: "unknown",
        class_name: "Smolagents::UnknownTool",
        registry_key: "unknown_tool",
        config: {}
      )

      expect { manifest.instantiate }.to raise_error(
        Smolagents::Persistence::UnknownToolError,
        /unknown_tool.*not in registry/
      )
    end
  end

  describe "#registry_tool?" do
    it "returns true for registered tools" do
      manifest = described_class.new(
        name: "final_answer",
        class_name: "Smolagents::FinalAnswerTool",
        registry_key: "final_answer",
        config: {}
      )

      expect(manifest.registry_tool?).to be true
    end

    it "returns false for unknown tools" do
      manifest = described_class.new(
        name: "custom",
        class_name: "CustomTool",
        registry_key: "custom_unknown",
        config: {}
      )

      expect(manifest.registry_tool?).to be false
    end
  end

  describe "round-trip serialization" do
    it "preserves data through to_h and from_h" do
      original = described_class.new(
        name: "duckduckgo_search",
        class_name: "Smolagents::DuckDuckGoSearchTool",
        registry_key: "duckduckgo_search",
        config: { max_results: 5 }
      )

      restored = described_class.from_h(original.to_h)

      expect(restored).to eq(original)
    end
  end
end
