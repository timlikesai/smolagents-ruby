require "spec_helper"

RSpec.describe Smolagents::Testing::ModelCapabilities::Inference do
  describe ".infer_speed" do
    it "returns :fast for small models" do
      expect(described_class.infer_speed("model-350m")).to eq(:fast)
      expect(described_class.infer_speed("micro-model")).to eq(:fast)
      expect(described_class.infer_speed("nano-model")).to eq(:fast)
      expect(described_class.infer_speed("tiny-model")).to eq(:fast)
      expect(described_class.infer_speed("model-1.2b")).to eq(:fast)
      expect(described_class.infer_speed("model-1b")).to eq(:fast)
    end

    it "returns :slow for large models" do
      expect(described_class.infer_speed("model-30b")).to eq(:slow)
      expect(described_class.infer_speed("model-20b")).to eq(:slow)
    end

    it "returns :medium for mid-size models" do
      expect(described_class.infer_speed("model-7b")).to eq(:medium)
      expect(described_class.infer_speed("gpt-4")).to eq(:medium)
      expect(described_class.infer_speed("llama-8b")).to eq(:medium)
    end
  end

  describe ".infer_size" do
    it "returns :tiny for very small models" do
      expect(described_class.infer_size("model-350m")).to eq(:tiny)
      expect(described_class.infer_size("micro-model")).to eq(:tiny)
      expect(described_class.infer_size("nano-model")).to eq(:tiny)
    end

    it "returns :small for small parameter counts" do
      expect(described_class.infer_size("model-1.2b")).to eq(:small)
      expect(described_class.infer_size("model-1b")).to eq(:small)
      expect(described_class.infer_size("model-2b")).to eq(:small)
      expect(described_class.infer_size("gemma-3n")).to eq(:small)
      expect(described_class.infer_size("model-3b")).to eq(:small)
      expect(described_class.infer_size("model-4b")).to eq(:small)
    end

    it "returns :medium for medium parameter counts" do
      expect(described_class.infer_size("model-7b")).to eq(:medium)
      expect(described_class.infer_size("model-8b")).to eq(:medium)
    end

    it "returns :large for unmatched patterns" do
      expect(described_class.infer_size("gpt-4")).to eq(:large)
      expect(described_class.infer_size("claude-opus")).to eq(:large)
      expect(described_class.infer_size("unknown-model")).to eq(:large)
    end
  end

  describe ".infer_specialization" do
    it "returns :vision for VLM models" do
      expect(described_class.infer_specialization("any-model", true)).to eq(:vision)
    end

    it "returns :code for code models" do
      expect(described_class.infer_specialization("coder-model", false)).to eq(:code)
      expect(described_class.infer_specialization("code-llama", false)).to eq(:code)
      expect(described_class.infer_specialization("deepseek-coder", false)).to eq(:code)
    end

    it "returns :general for other models" do
      expect(described_class.infer_specialization("gpt-4", false)).to eq(:general)
      expect(described_class.infer_specialization("llama-7b", false)).to eq(:general)
    end

    it "prioritizes vision over code for VLMs" do
      expect(described_class.infer_specialization("vision-coder", true)).to eq(:vision)
    end
  end

  describe ".infer_quantization" do
    it "returns :fp16 for full precision models" do
      expect(described_class.infer_quantization("model-fp16")).to eq(:fp16)
      expect(described_class.infer_quantization("model-bf16")).to eq(:fp16)
    end

    it "returns :int8 for 8-bit quantized models" do
      expect(described_class.infer_quantization("model-int8")).to eq(:int8)
      expect(described_class.infer_quantization("model-Q8")).to eq(:int8)
      expect(described_class.infer_quantization("model-w8")).to eq(:int8)
    end

    it "returns :int4 for 4-bit quantized models" do
      expect(described_class.infer_quantization("model-int4")).to eq(:int4)
      expect(described_class.infer_quantization("model-Q4")).to eq(:int4)
      expect(described_class.infer_quantization("model-w4")).to eq(:int4)
      expect(described_class.infer_quantization("model-iq4")).to eq(:int4)
      expect(described_class.infer_quantization("model-mxfp4")).to eq(:int4)
      expect(described_class.infer_quantization("model.gguf")).to eq(:int4)
      expect(described_class.infer_quantization("model.ggml")).to eq(:int4)
    end

    it "returns :unknown for unrecognized patterns" do
      expect(described_class.infer_quantization("model")).to eq(:unknown)
      expect(described_class.infer_quantization("gpt-4")).to eq(:unknown)
    end
  end

  describe ".infer_architecture" do
    it "returns :liquid for LFM models" do
      expect(described_class.infer_architecture("lfm-2.5")).to eq(:liquid)
      expect(described_class.infer_architecture("liquid-model")).to eq(:liquid)
    end

    it "returns :mamba for Mamba models" do
      expect(described_class.infer_architecture("mamba-2.8b")).to eq(:mamba)
    end

    it "returns :rwkv for RWKV models" do
      expect(described_class.infer_architecture("rwkv-6")).to eq(:rwkv)
    end

    it "returns :transformer for known transformer architectures" do
      expect(described_class.infer_architecture("gemma-7b")).to eq(:transformer)
      expect(described_class.infer_architecture("llama-3")).to eq(:transformer)
      expect(described_class.infer_architecture("qwen-2.5")).to eq(:transformer)
      expect(described_class.infer_architecture("granite-7b")).to eq(:transformer)
      expect(described_class.infer_architecture("gpt-4")).to eq(:transformer)
    end

    it "returns :unknown for unrecognized architectures" do
      expect(described_class.infer_architecture("custom-model")).to eq(:unknown)
    end
  end

  describe ".lm_studio_attrs" do
    it "returns complete attributes hash" do
      attrs = described_class.lm_studio_attrs("gemma-7b-Q8", 8192, false)

      expect(attrs).to include(
        model_id: "gemma-7b-Q8",
        context_length: 8192,
        vision: false,
        tool_use: true,
        reasoning: :basic,
        provider: :lm_studio
      )
    end

    it "infers speed from model name" do
      fast_attrs = described_class.lm_studio_attrs("nano-model", 4096, false)
      slow_attrs = described_class.lm_studio_attrs("model-30b", 4096, false)

      expect(fast_attrs[:speed]).to eq(:fast)
      expect(slow_attrs[:speed]).to eq(:slow)
    end

    it "infers size_category from model name" do
      tiny_attrs = described_class.lm_studio_attrs("micro-model", 4096, false)
      medium_attrs = described_class.lm_studio_attrs("model-7b", 4096, false)

      expect(tiny_attrs[:size_category]).to eq(:tiny)
      expect(medium_attrs[:size_category]).to eq(:medium)
    end

    it "infers specialization from model name and VLM flag" do
      vlm_attrs = described_class.lm_studio_attrs("model", 4096, true)
      code_attrs = described_class.lm_studio_attrs("coder-model", 4096, false)
      general_attrs = described_class.lm_studio_attrs("model", 4096, false)

      expect(vlm_attrs[:specialization]).to eq(:vision)
      expect(code_attrs[:specialization]).to eq(:code)
      expect(general_attrs[:specialization]).to eq(:general)
    end

    it "infers quantization from model name" do
      q8_attrs = described_class.lm_studio_attrs("model-Q8", 4096, false)
      gguf_attrs = described_class.lm_studio_attrs("model.gguf", 4096, false)

      expect(q8_attrs[:quantization]).to eq(:int8)
      expect(gguf_attrs[:quantization]).to eq(:int4)
    end

    it "infers architecture from model name" do
      llama_attrs = described_class.lm_studio_attrs("llama-7b", 4096, false)
      liquid_attrs = described_class.lm_studio_attrs("lfm-2.5", 4096, false)

      expect(llama_attrs[:architecture]).to eq(:transformer)
      expect(liquid_attrs[:architecture]).to eq(:liquid)
    end
  end
end
