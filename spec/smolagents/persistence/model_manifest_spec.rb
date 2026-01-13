RSpec.describe Smolagents::Persistence::ModelManifest do
  let(:mock_model) do
    model = Smolagents::Model.new(model_id: "gpt-4")
    model.instance_variable_set(:@temperature, 0.7)
    model.instance_variable_set(:@max_tokens, 1000)
    model
  end

  describe ".from_model" do
    it "captures model class and id" do
      manifest = described_class.from_model(mock_model)

      expect(manifest.class_name).to eq("Smolagents::Models::Model")
      expect(manifest.model_id).to eq("gpt-4")
    end

    it "captures non-sensitive config" do
      manifest = described_class.from_model(mock_model)

      expect(manifest.config[:temperature]).to eq(0.7)
      expect(manifest.config[:max_tokens]).to eq(1000)
    end

    it "excludes sensitive data" do
      mock_model.instance_variable_set(:@api_key, "secret-key")
      mock_model.instance_variable_set(:@access_token, "secret-token")
      mock_model.instance_variable_set(:@password, "secret-pass")

      manifest = described_class.from_model(mock_model)

      expect(manifest.config.keys).not_to include(:api_key)
      expect(manifest.config.keys).not_to include(:access_token)
      expect(manifest.config.keys).not_to include(:password)
    end

    it "excludes non-serializable objects" do
      mock_model.instance_variable_set(:@client, Object.new)
      mock_model.instance_variable_set(:@logger, Logger.new(nil))

      manifest = described_class.from_model(mock_model)

      expect(manifest.config.keys).not_to include(:client)
      expect(manifest.config.keys).not_to include(:logger)
    end
  end

  describe "#to_h" do
    it "returns a serializable hash" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gemma-3n-e4b-it-q8_0",
        provider: :lm_studio,
        config: { temperature: 0.7 }
      )

      hash = manifest.to_h

      expect(hash).to eq({
                           class_name: "Smolagents::OpenAIModel",
                           model_id: "gemma-3n-e4b-it-q8_0",
                           provider: :lm_studio,
                           config: { temperature: 0.7 }
                         })
    end
  end

  describe ".from_h" do
    it "reconstructs from hash with symbol keys" do
      hash = { class_name: "Smolagents::Model", model_id: "gpt-4", config: { temperature: 0.5 } }

      manifest = described_class.from_h(hash)

      expect(manifest.class_name).to eq("Smolagents::Model")
      expect(manifest.model_id).to eq("gpt-4")
      expect(manifest.config[:temperature]).to eq(0.5)
    end

    it "reconstructs from hash with string keys" do
      hash = { "class_name" => "Smolagents::Model", "model_id" => "gpt-4", "config" => { "temperature" => 0.5 } }

      manifest = described_class.from_h(hash)

      expect(manifest.class_name).to eq("Smolagents::Model")
      expect(manifest.config[:temperature]).to eq(0.5)
    end
  end

  describe "round-trip serialization" do
    it "preserves data through to_h and from_h" do
      original = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-oss-20b-mxfp4",
        provider: :llama_cpp,
        config: { temperature: 0.9, max_tokens: 2000 }
      )

      restored = described_class.from_h(original.to_h)

      expect(restored).to eq(original)
    end
  end

  describe "#local?" do
    it "returns true for local providers" do
      Smolagents::Persistence::LOCAL_PROVIDERS.each do |provider|
        manifest = described_class.new(
          class_name: "Smolagents::OpenAIModel",
          model_id: "test-model",
          provider: provider,
          config: {}
        )
        expect(manifest.local?).to be true
      end
    end

    it "returns false for cloud providers" do
      %i[openai anthropic azure gemini].each do |provider|
        manifest = described_class.new(
          class_name: "Smolagents::OpenAIModel",
          model_id: "test-model",
          provider: provider,
          config: {}
        )
        expect(manifest.local?).to be false
      end
    end
  end

  describe "#auto_instantiate" do
    it "returns nil for cloud providers without env key" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "test-model",
        provider: :openai,
        config: {}
      )

      # Temporarily remove env var
      original_key = ENV.fetch("OPENAI_API_KEY", nil)
      ENV.delete("OPENAI_API_KEY")

      expect(manifest.auto_instantiate).to be_nil

      ENV["OPENAI_API_KEY"] = original_key if original_key
    end
  end

  describe ".detect_provider" do
    it "detects lm_studio from localhost:1234 URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://localhost:1234/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:lm_studio)
    end

    it "detects ollama from localhost:11434 URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://localhost:11434/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:ollama)
    end

    it "detects llama_cpp from localhost:8080 URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://localhost:8080/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:llama_cpp)
    end
  end
end
