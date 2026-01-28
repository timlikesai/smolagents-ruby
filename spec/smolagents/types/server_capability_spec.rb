RSpec.describe Smolagents::Types::ServerType do
  describe ".lookup" do
    it "returns server type for valid name" do
      type = described_class.lookup(:llama_cpp)
      expect(type.name).to eq(:llama_cpp)
      expect(type.base_capabilities[:tools]).to be true
    end

    it "returns nil for unknown name" do
      expect(described_class.lookup(:unknown)).to be_nil
    end

    it "looks up lm_studio with model-dependent tools, no json_object, and capability query support" do
      type = described_class.lookup(:lm_studio)
      expect(type.base_capabilities[:tools]).to eq(:model_dependent)  # Native for Qwen 2.5, Llama 3.x
      expect(type.base_capabilities[:json_object]).to be false        # 400 error
      expect(type.base_capabilities[:json_schema]).to be true         # Works with full schema
      expect(type.base_capabilities[:stop_array]).to be true
      expect(type.base_capabilities[:tools_response_format_conflict]).to be false  # Can use both
      expect(type.base_capabilities[:supports_capability_query]).to be true        # /v1/models has caps
    end

    it "looks up llama_cpp with tools/response_format conflict" do
      type = described_class.lookup(:llama_cpp)
      expect(type.base_capabilities[:tools]).to be true
      expect(type.base_capabilities[:json_object]).to be true
      expect(type.base_capabilities[:json_schema]).to be true
      expect(type.base_capabilities[:tools_response_format_conflict]).to be true # Cannot use both!
      expect(type.base_capabilities[:supports_capability_query]).to be false
    end

    it "looks up mlx_lm with model-dependent tools" do
      type = described_class.lookup(:mlx_lm)
      expect(type.base_capabilities[:tools]).to eq(:model_dependent)
      expect(type.base_capabilities[:json_object]).to be false
      expect(type.base_capabilities[:json_schema]).to be false
    end
  end

  describe ".infer_from_url" do
    it "infers llama_cpp from URL" do
      type = described_class.infer_from_url("https://llama-cpp-ultra.example.com/v1")
      expect(type.name).to eq(:llama_cpp)
    end

    it "infers lm_studio from port 1234" do
      type = described_class.infer_from_url("http://localhost:1234/v1")
      expect(type.name).to eq(:lm_studio)
    end

    it "infers ollama from port 11434" do
      type = described_class.infer_from_url("http://localhost:11434/v1")
      expect(type.name).to eq(:ollama)
    end

    it "defaults to openai for unknown URLs" do
      type = described_class.infer_from_url("https://api.example.com/v1")
      expect(type.name).to eq(:openai)
    end
  end
end

RSpec.describe Smolagents::Types::ServerCapability do
  describe ".from_server_type" do
    it "builds capability from llama_cpp server type" do
      type = Smolagents::Types::ServerType.lookup(:llama_cpp)
      cap = described_class.from_server_type(type)

      expect(cap.supports_tools).to be true
      expect(cap.supports_json_object).to be true
      expect(cap.supports_json_schema).to be true
      expect(cap.supports_stop_array).to be true
      expect(cap.confidence).to eq(:base)
    end

    it "captures lm_studio capabilities correctly" do
      type = Smolagents::Types::ServerType.lookup(:lm_studio)
      cap = described_class.from_server_type(type)

      expect(cap.supports_tools).to eq(:model_dependent)  # Native for some models, fallback for others
      expect(cap.supports_json_object).to be false        # Returns 400 error
      expect(cap.supports_json_schema).to be true         # Works with full schema
      expect(cap.supports_stop_array).to be true
      expect(cap.tools_response_format_conflict?).to be false  # Can use both together
      expect(cap.supports_capability_query).to be true         # /v1/models returns capabilities
    end

    it "captures llama_cpp tools/response_format conflict" do
      type = Smolagents::Types::ServerType.lookup(:llama_cpp)
      cap = described_class.from_server_type(type)

      expect(cap.supports_tools).to be true
      expect(cap.supports_json_object).to be true
      expect(cap.supports_json_schema).to be true
      expect(cap.tools_response_format_conflict?).to be true  # CRITICAL: Cannot use both
    end

    it "captures mlx_lm capabilities correctly" do
      type = Smolagents::Types::ServerType.lookup(:mlx_lm)
      cap = described_class.from_server_type(type)

      expect(cap.supports_tools).to eq(:model_dependent)
      expect(cap.supports_json_object).to be false
      expect(cap.supports_json_schema).to be false
      expect(cap.supports_stop_array).to be true
    end
  end

  describe ".from_url" do
    it "infers lm_studio capabilities from port 1234" do
      cap = described_class.from_url("http://localhost:1234/v1")
      expect(cap.supports_tools).to eq(:model_dependent)
      expect(cap.supports_json_object).to be false
      expect(cap.supports_json_schema).to be true
      expect(cap.server_type.name).to eq(:lm_studio)
      expect(cap.tools_response_format_conflict?).to be false
    end

    it "infers llama_cpp capabilities from URL pattern" do
      cap = described_class.from_url("https://llama-cpp-server.example.com/v1")
      expect(cap.supports_tools).to be true
      expect(cap.supports_json_object).to be true
      expect(cap.supports_json_schema).to be true
      expect(cap.tools_response_format_conflict?).to be true  # CRITICAL conflict
    end
  end

  describe "#with_learned" do
    it "updates capability and sets confidence to learned" do
      cap = described_class.from_url("http://localhost:1234/v1")
      expect(cap.supports_json_object).to be false

      learned = cap.with_learned(:supports_json_object, true)
      expect(learned.supports_json_object).to be true
      expect(learned.confidence).to eq(:learned)
      expect(learned.learned?).to be true
    end

    it "preserves other capabilities" do
      cap = described_class.from_url("http://localhost:1234/v1")
      learned = cap.with_learned(:supports_json_object, true)

      expect(learned.supports_tools).to eq(cap.supports_tools)
      expect(learned.supports_stop_array).to eq(cap.supports_stop_array)
    end
  end

  describe "#base?" do
    it "returns true for base capabilities" do
      cap = described_class.from_url("http://localhost:1234/v1")
      expect(cap.base?).to be true
    end

    it "returns false after learning" do
      cap = described_class.from_url("http://localhost:1234/v1")
      learned = cap.with_learned(:supports_json_object, true)
      expect(learned.base?).to be false
    end
  end

  describe ".from_lm_studio_probe" do
    let(:model_caps) do
      Smolagents::Concerns::Resilience::LmStudioProbe::ModelCapabilities.new(
        model_key: "qwen3-coder-30b",
        trained_for_tool_use: true,
        vision: false,
        max_context_length: 262_144,
        format: "mlx",
        architecture: "qwen3",
        quantization: "8bit"
      )
    end

    let(:vision_model_caps) do
      Smolagents::Concerns::Resilience::LmStudioProbe::ModelCapabilities.new(
        model_key: "gemma-3n",
        trained_for_tool_use: false,
        vision: true,
        max_context_length: 32_768,
        format: "mlx",
        architecture: "gemma3n",
        quantization: nil
      )
    end

    it "builds capability from probe result with tool support" do
      cap = described_class.from_lm_studio_probe(model_caps)

      expect(cap.supports_tools).to be true
      expect(cap.supports_vision).to be false
      expect(cap.max_context_length).to eq(262_144)
      expect(cap.confidence).to eq(:probed)
      expect(cap.probed?).to be true
    end

    it "builds capability from probe result with vision support" do
      cap = described_class.from_lm_studio_probe(vision_model_caps)

      expect(cap.supports_tools).to be false
      expect(cap.supports_vision).to be true
      expect(cap.vision?).to be true
      expect(cap.max_context_length).to eq(32_768)
    end

    it "preserves LM Studio server type characteristics" do
      cap = described_class.from_lm_studio_probe(model_caps)

      expect(cap.server_type.name).to eq(:lm_studio)
      expect(cap.supports_json_object).to be false     # LM Studio doesn't support json_object
      expect(cap.supports_json_schema).to be true      # LM Studio supports json_schema
      expect(cap.tools_response_format_conflict?).to be false
      expect(cap.supports_capability_query).to be true
    end
  end

  describe "#probed?" do
    it "returns false for base capabilities" do
      cap = described_class.from_url("http://localhost:1234/v1")
      expect(cap.probed?).to be false
    end

    it "returns true for probed capabilities" do
      model_caps = Smolagents::Concerns::Resilience::LmStudioProbe::ModelCapabilities.new(
        model_key: "test",
        trained_for_tool_use: true,
        vision: false,
        max_context_length: 128_000,
        format: "mlx",
        architecture: "test",
        quantization: nil
      )
      cap = described_class.from_lm_studio_probe(model_caps)
      expect(cap.probed?).to be true
    end
  end

  describe "#vision?" do
    it "returns true when vision is supported" do
      model_caps = Smolagents::Concerns::Resilience::LmStudioProbe::ModelCapabilities.new(
        model_key: "vision-model",
        trained_for_tool_use: false,
        vision: true,
        max_context_length: 32_768,
        format: "mlx",
        architecture: "test",
        quantization: nil
      )
      cap = described_class.from_lm_studio_probe(model_caps)
      expect(cap.vision?).to be true
    end

    it "returns false when vision is not supported" do
      cap = described_class.from_url("http://localhost:1234/v1")
      expect(cap.vision?).to be false
    end
  end
end
