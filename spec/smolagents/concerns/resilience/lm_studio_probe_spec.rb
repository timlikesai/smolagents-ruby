require "webmock/rspec"

RSpec.describe Smolagents::Concerns::Resilience::LmStudioProbe do
  let(:base_url) { "http://localhost:1234" }

  # Sample response matching LM Studio 0.4.0 /api/v1/models format
  let(:models_response) do
    {
      models: [
        {
          type: "llm",
          key: "qwen3-coder-30b",
          display_name: "Qwen3 Coder 30B",
          architecture: "qwen3",
          max_context_length: 262_144,
          format: "mlx",
          capabilities: {
            vision: false,
            trained_for_tool_use: true
          },
          quantization: { name: "8bit", bits_per_weight: 8 }
        },
        {
          type: "llm",
          key: "glm-4.7-flash",
          display_name: "GLM 4.7 Flash",
          architecture: "glm4_moe_lite",
          max_context_length: 202_752,
          format: "mlx",
          capabilities: {
            vision: false,
            trained_for_tool_use: true
          },
          quantization: { name: "4bit", bits_per_weight: 4 }
        },
        {
          type: "llm",
          key: "gemma-3n-e4b",
          display_name: "Gemma 3n E4B",
          architecture: "gemma3n",
          max_context_length: 32_768,
          format: "mlx",
          capabilities: {
            vision: true,
            trained_for_tool_use: false
          },
          quantization: nil
        },
        {
          type: "embedding",
          key: "nomic-embed-text",
          display_name: "Nomic Embed Text",
          max_context_length: 2048,
          format: "gguf",
          capabilities: {
            vision: nil,
            trained_for_tool_use: nil
          }
        }
      ]
    }
  end

  describe ".probe" do
    context "when server responds successfully" do
      before do
        stub_request(:get, "#{base_url}/api/v1/models")
          .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns successful result with parsed models" do
        result = described_class.probe(base_url)

        expect(result).to be_success
        expect(result.models.size).to eq(3) # Excludes embedding model
        expect(result.error).to be_nil
      end

      it "parses model capabilities correctly" do
        result = described_class.probe(base_url)
        qwen = result.models.find { |m| m.model_key == "qwen3-coder-30b" }

        expect(qwen.trained_for_tool_use).to be true
        expect(qwen.vision).to be false
        expect(qwen.max_context_length).to eq(262_144)
        expect(qwen.format).to eq("mlx")
        expect(qwen.architecture).to eq("qwen3")
        expect(qwen.quantization).to eq("8bit (8bit)")
      end

      it "identifies vision-capable models" do
        result = described_class.probe(base_url)
        gemma = result.models.find { |m| m.model_key == "gemma-3n-e4b" }

        expect(gemma.vision).to be true
        expect(gemma.trained_for_tool_use).to be false
        expect(gemma.vision_supported?).to be true
        expect(gemma.tools_supported?).to be false
      end

      it "excludes embedding models" do
        result = described_class.probe(base_url)
        embedding = result.models.find { |m| m.model_key == "nomic-embed-text" }

        expect(embedding).to be_nil
      end
    end

    context "when server returns error" do
      before do
        stub_request(:get, "#{base_url}/api/v1/models")
          .to_return(status: 500, body: '{"error": "Internal Server Error"}')
      end

      it "returns failed result with error message" do
        result = described_class.probe(base_url)

        expect(result).to be_failed
        expect(result.error).to include("HTTP 500")
        expect(result.models).to be_empty
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "#{base_url}/api/v1/models")
          .to_timeout
      end

      it "returns failed result with error message" do
        result = described_class.probe(base_url)

        expect(result).to be_failed
        expect(result.error).not_to be_nil
        expect(result.models).to be_empty
      end
    end
  end

  describe ".probe_model" do
    before do
      stub_request(:get, "#{base_url}/api/v1/models")
        .to_return(status: 200, body: models_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns capabilities for exact model key match" do
      caps = described_class.probe_model(base_url, "qwen3-coder-30b")

      expect(caps).not_to be_nil
      expect(caps.trained_for_tool_use).to be true
    end

    it "returns nil for non-existent model" do
      caps = described_class.probe_model(base_url, "nonexistent-model")

      expect(caps).to be_nil
    end

    it "matches when model_id contains model key" do
      # model_matches? checks: model_id.include?(model.model_key)
      # So passing a longer string that contains the key works
      caps = described_class.probe_model(base_url, "lmstudio/glm-4.7-flash")

      expect(caps).not_to be_nil
      expect(caps.model_key).to eq("glm-4.7-flash")
    end
  end

  describe "ServerProbeResult#find_model" do
    before do
      stub_request(:get, "#{base_url}/api/v1/models")
        .to_return(status: 200, body: models_response.to_json)
    end

    it "finds model by exact key" do
      result = described_class.probe(base_url)
      model = result.find_model("qwen3-coder-30b")

      expect(model).not_to be_nil
      expect(model.model_key).to eq("qwen3-coder-30b")
    end

    it "finds model when model_id contains the key" do
      result = described_class.probe(base_url)
      # model_matches? checks: model_id.include?(model.model_key)
      model = result.find_model("mlx-community/qwen3-coder-30b")

      expect(model).not_to be_nil
      expect(model.model_key).to eq("qwen3-coder-30b")
    end
  end

  describe "ModelCapabilities" do
    let(:caps) do
      described_class::ModelCapabilities.new(
        model_key: "test-model",
        trained_for_tool_use: true,
        vision: false,
        max_context_length: 128_000,
        format: "mlx",
        architecture: "test",
        quantization: "8bit"
      )
    end

    it "provides tools_supported? predicate" do
      expect(caps.tools_supported?).to be true
    end

    it "provides vision_supported? predicate" do
      expect(caps.vision_supported?).to be false
    end
  end
end
