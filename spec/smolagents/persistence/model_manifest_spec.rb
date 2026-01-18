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

    it "excludes all sensitive keys from the MODEL_SENSITIVE_KEYS list" do
      sensitive_keys = %i[api_key access_token auth_token bearer_token password secret credential api_secret
                          private_key]
      sensitive_keys.each do |key|
        model = Smolagents::Model.new(model_id: "test")
        model.instance_variable_set(:"@#{key}", "sensitive-value")

        manifest = described_class.from_model(model)

        expect(manifest.config.keys).not_to include(key), "Expected #{key} to be excluded"
      end
    end

    it "excludes non-serializable keys from the MODEL_NON_SERIALIZABLE list" do
      non_serializable_keys = %i[client logger model_id kwargs]
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@client, Object.new)
      model.instance_variable_set(:@logger, Logger.new(nil))
      model.instance_variable_set(:@model_id, "should-be-excluded-ivar")
      model.instance_variable_set(:@kwargs, { complex: Object.new })

      manifest = described_class.from_model(model)

      non_serializable_keys.each do |key|
        expect(manifest.config.keys).not_to include(key), "Expected #{key} to be excluded"
      end
    end

    it "preserves primitive values in config" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@temperature, 0.5)
      model.instance_variable_set(:@max_tokens, 500)
      model.instance_variable_set(:@enabled, true)
      model.instance_variable_set(:@description, "test model")
      model.instance_variable_set(:@top_p, 0.95)

      manifest = described_class.from_model(model)

      expect(manifest.config[:temperature]).to eq(0.5)
      expect(manifest.config[:max_tokens]).to eq(500)
      expect(manifest.config[:enabled]).to be true
      expect(manifest.config[:description]).to eq("test model")
      expect(manifest.config[:top_p]).to eq(0.95)
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

    it "returns hash with all fields intact" do
      manifest = described_class.new(
        class_name: "Smolagents::AnthropicModel",
        model_id: "claude-3",
        provider: :anthropic,
        config: { temperature: 0.9, max_tokens: 4096, api_base: "https://api.anthropic.com" }
      )

      hash = manifest.to_h

      expect(hash[:class_name]).to eq("Smolagents::AnthropicModel")
      expect(hash[:model_id]).to eq("claude-3")
      expect(hash[:provider]).to eq(:anthropic)
      expect(hash[:config]).to include(temperature: 0.9, max_tokens: 4096)
    end

    it "returns hash with empty config when no config is present" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: {}
      )

      hash = manifest.to_h

      expect(hash[:config]).to eq({})
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

    it "handles missing provider gracefully" do
      hash = { class_name: "Smolagents::Model", model_id: "test", config: {} }

      manifest = described_class.from_h(hash)

      expect(manifest.provider).to be_nil
    end

    it "handles nil provider gracefully" do
      hash = { class_name: "Smolagents::Model", model_id: "test", provider: nil, config: {} }

      manifest = described_class.from_h(hash)

      expect(manifest.provider).to be_nil
    end

    it "converts provider string to symbol" do
      hash = { "class_name" => "Smolagents::OpenAIModel", "model_id" => "gpt-4", "provider" => "lm_studio", "config" => {} }

      manifest = described_class.from_h(hash)

      expect(manifest.provider).to eq(:lm_studio)
      expect(manifest.provider).to be_a(Symbol)
    end

    it "preserves provider as symbol when already symbol" do
      hash = { class_name: "Smolagents::OpenAIModel", model_id: "gpt-4", provider: :ollama, config: {} }

      manifest = described_class.from_h(hash)

      expect(manifest.provider).to eq(:ollama)
      expect(manifest.provider).to be_a(Symbol)
    end

    it "handles missing config gracefully" do
      hash = { class_name: "Smolagents::Model", model_id: "test" }

      manifest = described_class.from_h(hash)

      expect(manifest.config).to eq({})
    end

    it "handles nil config gracefully" do
      hash = { class_name: "Smolagents::Model", model_id: "test", config: nil }

      manifest = described_class.from_h(hash)

      expect(manifest.config).to eq({})
    end

    it "symbolizes top-level config keys" do
      hash = {
        "class_name" => "Smolagents::OpenAIModel",
        "model_id" => "gpt-4",
        "provider" => "openai",
        "config" => {
          "temperature" => 0.5,
          "api_base" => "https://api.example.com",
          "array" => [1, 2, 3]
        }
      }

      manifest = described_class.from_h(hash)

      expect(manifest.config[:temperature]).to eq(0.5)
      expect(manifest.config[:api_base]).to eq("https://api.example.com")
      expect(manifest.config[:array]).to eq([1, 2, 3])
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

    it "preserves complex config through roundtrip" do
      original = described_class.new(
        class_name: "Smolagents::AnthropicModel",
        model_id: "claude-3-sonnet",
        provider: :anthropic,
        config: {
          temperature: 0.7,
          max_tokens: 4096,
          api_base: "https://api.anthropic.com",
          top_p: 0.95,
          top_k: 50
        }
      )

      restored = described_class.from_h(original.to_h)

      expect(restored.class_name).to eq(original.class_name)
      expect(restored.model_id).to eq(original.model_id)
      expect(restored.provider).to eq(original.provider)
      expect(restored.config).to eq(original.config)
    end

    it "preserves nil provider through roundtrip" do
      original = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "test",
        provider: nil,
        config: {}
      )

      restored = described_class.from_h(original.to_h)

      expect(restored.provider).to be_nil
      expect(restored).to eq(original)
    end

    it "preserves empty config through roundtrip" do
      original = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "test",
        provider: :openai,
        config: {}
      )

      restored = described_class.from_h(original.to_h)

      expect(restored.config).to eq({})
      expect(restored).to eq(original)
    end
  end

  describe "#local?" do
    it "returns true for local providers" do
      Smolagents::Persistence::ModelManifestSupport::LOCAL_PROVIDERS.each do |provider|
        manifest = described_class.new(
          class_name: "Smolagents::OpenAIModel",
          model_id: "test-model",
          provider:,
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
          provider:,
          config: {}
        )
        expect(manifest.local?).to be false
      end
    end

    it "returns false for nil provider" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "test-model",
        provider: nil,
        config: {}
      )
      expect(manifest.local?).to be false
    end

    it "returns false for unknown provider" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "test-model",
        provider: :unknown_provider,
        config: {}
      )
      expect(manifest.local?).to be false
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

    it "returns nil when auto_instantiate encounters error" do
      manifest = described_class.new(
        class_name: "NonExistentModel",
        model_id: "test",
        provider: :openai,
        config: {}
      )

      expect(manifest.auto_instantiate).to be_nil
    end

    it "returns nil for untrusted class" do
      manifest = described_class.new(
        class_name: "SomeRandomClass",
        model_id: "test",
        provider: :openai,
        config: {}
      )

      expect(manifest.auto_instantiate).to be_nil
    end

    it "returns model when api_key is provided explicitly" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: {}
      )

      model = manifest.auto_instantiate(api_key: "test-key")

      expect(model).to be_a(Smolagents::OpenAIModel)
      expect(model.model_id).to eq("gpt-4")
    end

    it "accepts overrides parameter" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: { temperature: 0.5 }
      )

      model = manifest.auto_instantiate(api_key: "test-key", temperature: 0.8)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe "#instantiate" do
    it "raises UntrustedClassError for non-allowlisted class" do
      manifest = described_class.new(
        class_name: "SomeRandomClass",
        model_id: "test",
        provider: :openai,
        config: {}
      )

      expect do
        manifest.instantiate(api_key: "test-key")
      end.to raise_error(Smolagents::Persistence::UntrustedClassError) do |error|
        expect(error.class_name).to eq("SomeRandomClass")
        expect(error.allowed_classes).to include("Smolagents::OpenAIModel")
      end
    end

    it "instantiates allowlisted OpenAIModel" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: { temperature: 0.7 }
      )

      model = manifest.instantiate(api_key: "test-key")

      expect(model).to be_a(Smolagents::OpenAIModel)
      expect(model.model_id).to eq("gpt-4")
    end

    it "instantiates allowlisted AnthropicModel" do
      manifest = described_class.new(
        class_name: "Smolagents::AnthropicModel",
        model_id: "claude-3",
        provider: :anthropic,
        config: {}
      )

      model = manifest.instantiate(api_key: "test-key")

      expect(model).to be_a(Smolagents::AnthropicModel)
      expect(model.model_id).to eq("claude-3")
    end

    it "instantiates allowlisted LiteLLMModel" do
      manifest = described_class.new(
        class_name: "Smolagents::LiteLLMModel",
        model_id: "ollama/mistral",
        provider: :ollama,
        config: {}
      )

      model = manifest.instantiate(api_key: "not-needed")

      expect(model).to be_a(Smolagents::LiteLLMModel)
      expect(model.model_id).to eq("ollama/mistral")
    end

    it "merges overrides with config" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: { temperature: 0.5, max_tokens: 1000 }
      )

      model = manifest.instantiate(api_key: "test-key", temperature: 0.9)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "passes api_key to models that accept it" do
      manifest = described_class.new(
        class_name: "Smolagents::OpenAIModel",
        model_id: "gpt-4",
        provider: :openai,
        config: {}
      )

      model = manifest.instantiate(api_key: "my-secret-key")

      expect(model).to be_a(Smolagents::OpenAIModel)
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

    it "detects vllm from localhost:8000 URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://localhost:8000/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:vllm)
    end

    it "detects azure from azure.com URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "https://test.openai.azure.com/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:azure)
    end

    it "detects lm_studio from lm.studio domain" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "https://api.lm.studio/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:lm_studio)
    end

    it "detects ollama from ollama domain" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://ollama.local:11434/api")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:ollama)
    end

    it "detects vllm from vllm domain" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "http://vllm.example.com/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:vllm)
    end

    it "defaults to openai for unknown URL" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@api_base, "https://custom-api.example.com/v1")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:openai)
    end

    it "uses provider from config if present" do
      model = Smolagents::Model.new(model_id: "test")
      model.instance_variable_set(:@provider, "custom_provider")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:custom_provider)
    end

    it "detects anthropic for AnthropicModel" do
      # Create a mock that behaves like AnthropicModel
      model = Smolagents::Model.new(model_id: "test")
      allow(model).to receive(:class).and_return(
        double(name: "Smolagents::AnthropicModel")
      )

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:anthropic)
    end

    it "defaults to openai for unknown model type" do
      model = Smolagents::Model.new(model_id: "test")

      manifest = described_class.from_model(model)

      expect(manifest.provider).to eq(:openai)
    end
  end
end
