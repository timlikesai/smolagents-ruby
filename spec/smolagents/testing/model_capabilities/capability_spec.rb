RSpec.describe Smolagents::Testing::ModelCapabilities::Capability do
  describe "initialization" do
    it "creates a Capability with all attributes", max_time: 0.15 do
      capability = described_class.new(
        model_id: "gpt-4",
        context_length: 8192,
        vision: true,
        tool_use: true,
        reasoning: :strong,
        speed: :fast,
        size_category: :large,
        specialization: :general,
        provider: :openai,
        quantization: :fp16,
        architecture: :transformer
      )

      expect(capability.model_id).to eq("gpt-4")
      expect(capability.context_length).to eq(8192)
      expect(capability.vision).to be true
      expect(capability.tool_use).to be true
      expect(capability.reasoning).to eq(:strong)
      expect(capability.speed).to eq(:fast)
      expect(capability.size_category).to eq(:large)
      expect(capability.specialization).to eq(:general)
      expect(capability.provider).to eq(:openai)
      expect(capability.quantization).to eq(:fp16)
      expect(capability.architecture).to eq(:transformer)
    end
  end

  describe ".from_lm_studio" do
    it "creates Capability from LM Studio model info" do
      model_info = {
        "id" => "test-model",
        "max_context_length" => 4096,
        "type" => "model"
      }

      capability = described_class.from_lm_studio(model_info)

      expect(capability.model_id).to eq("test-model")
      expect(capability.context_length).to eq(4096)
    end

    it "infers vision from model type" do
      vlm_info = {
        "id" => "vision-model",
        "max_context_length" => 4096,
        "type" => "vlm"
      }

      capability = described_class.from_lm_studio(vlm_info)

      expect(capability.vision).to be true
    end

    it "handles missing context_length with default" do
      model_info = {
        "id" => "model",
        "type" => "model"
      }

      capability = described_class.from_lm_studio(model_info)

      expect(capability.context_length).to eq(4096)
    end
  end

  describe "#vision?" do
    it "returns true when vision is true" do
      capability = described_class.new(
        model_id: "vision-model",
        context_length: 4096,
        vision: true,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.vision?).to be true
    end

    it "returns false when vision is false" do
      capability = described_class.new(
        model_id: "text-model",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.vision?).to be false
    end
  end

  describe "#tool_use?" do
    it "returns true when tool_use is true" do
      capability = described_class.new(
        model_id: "tool-capable",
        context_length: 4096,
        vision: false,
        tool_use: true,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.tool_use?).to be true
    end

    it "returns false when tool_use is false" do
      capability = described_class.new(
        model_id: "basic-model",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.tool_use?).to be false
    end
  end

  describe "#fast?" do
    it "returns true when speed is :fast" do
      capability = described_class.new(
        model_id: "fast-model",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :fast,
        size_category: :small,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.fast?).to be true
    end

    it "returns false when speed is not :fast" do
      capability = described_class.new(
        model_id: "slow-model",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :slow,
        size_category: :large,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.fast?).to be false
    end
  end

  describe "#large_context?" do
    it "returns true for context >= 100k tokens" do
      capability = described_class.new(
        model_id: "long-context",
        context_length: 100_000,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.large_context?).to be true
    end

    it "returns true for context > 100k tokens" do
      capability = described_class.new(
        model_id: "ultra-long-context",
        context_length: 131_072,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.large_context?).to be true
    end

    it "returns false for context < 100k tokens" do
      capability = described_class.new(
        model_id: "short-context",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :small,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.large_context?).to be false
    end
  end

  describe "#can_reason?" do
    it "returns true for :basic reasoning" do
      capability = described_class.new(
        model_id: "reasonable",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.can_reason?).to be true
    end

    it "returns true for :strong reasoning" do
      capability = described_class.new(
        model_id: "smart",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :strong,
        speed: :medium,
        size_category: :large,
        specialization: :reasoning,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.can_reason?).to be true
    end

    it "returns false for :minimal reasoning" do
      capability = described_class.new(
        model_id: "basic",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :minimal,
        speed: :fast,
        size_category: :tiny,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.can_reason?).to be false
    end
  end

  describe "#recommended_max_steps" do
    it "returns 4 for minimal reasoning" do
      capability = described_class.new(
        model_id: "basic",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :minimal,
        speed: :medium,
        size_category: :small,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_max_steps).to eq(4)
    end

    it "returns 6 for basic reasoning" do
      capability = described_class.new(
        model_id: "intermediate",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_max_steps).to eq(6)
    end

    it "returns 10 for strong reasoning" do
      capability = described_class.new(
        model_id: "advanced",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :strong,
        speed: :medium,
        size_category: :large,
        specialization: :reasoning,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_max_steps).to eq(10)
    end
  end

  describe "#recommended_timeout" do
    it "returns 30 for fast speed" do
      capability = described_class.new(
        model_id: "fast",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :fast,
        size_category: :small,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_timeout).to eq(30)
    end

    it "returns 60 for medium speed" do
      capability = described_class.new(
        model_id: "medium",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_timeout).to eq(60)
    end

    it "returns 120 for slow speed" do
      capability = described_class.new(
        model_id: "slow",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :slow,
        size_category: :large,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability.recommended_timeout).to eq(120)
    end
  end

  describe "#to_h" do
    it "returns all attributes as hash" do
      capability = described_class.new(
        model_id: "gpt-4",
        context_length: 8192,
        vision: true,
        tool_use: true,
        reasoning: :strong,
        speed: :fast,
        size_category: :large,
        specialization: :general,
        provider: :openai,
        quantization: :fp16,
        architecture: :transformer
      )

      hash = capability.to_h

      expect(hash).to include(
        model_id: "gpt-4",
        context_length: 8192,
        vision: true,
        tool_use: true,
        reasoning: :strong,
        speed: :fast,
        size_category: :large,
        specialization: :general,
        provider: :openai,
        quantization: :fp16,
        architecture: :transformer
      )
    end
  end

  describe "Data.define behavior" do
    it "is immutable" do
      capability = described_class.new(
        model_id: "test",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      expect(capability).to be_frozen
    end

    it "supports pattern matching" do
      capability = described_class.new(
        model_id: "test-model",
        context_length: 4096,
        vision: false,
        tool_use: false,
        reasoning: :basic,
        speed: :medium,
        size_category: :medium,
        specialization: :general,
        provider: :openai,
        quantization: :unknown,
        architecture: :transformer
      )

      matched = case capability
                in { model_id: "test-model", reasoning: :basic }
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end
end
