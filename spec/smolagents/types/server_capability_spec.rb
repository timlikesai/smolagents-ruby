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

    it "looks up lm_studio with tools but no json_object" do
      type = described_class.lookup(:lm_studio)
      expect(type.base_capabilities[:tools]).to be true
      expect(type.base_capabilities[:json_object]).to be false  # 400 error
      expect(type.base_capabilities[:json_schema]).to be true   # Works with full schema
      expect(type.base_capabilities[:stop_array]).to be true
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

      expect(cap.supports_tools).to be true           # LM Studio supports tools!
      expect(cap.supports_json_object).to be false    # Returns 400 error
      expect(cap.supports_json_schema).to be true     # Works with full schema
      expect(cap.supports_stop_array).to be true
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
      expect(cap.supports_tools).to be true
      expect(cap.supports_json_object).to be false
      expect(cap.supports_json_schema).to be true
      expect(cap.server_type.name).to eq(:lm_studio)
    end

    it "infers llama_cpp capabilities from URL pattern" do
      cap = described_class.from_url("https://llama-cpp-server.example.com/v1")
      expect(cap.supports_tools).to be true
      expect(cap.supports_json_object).to be true
      expect(cap.supports_json_schema).to be true
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
end
