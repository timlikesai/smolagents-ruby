require "spec_helper"

RSpec.describe Smolagents::Persistence::ModelManifestSupport do
  describe "SENSITIVE_KEYS" do
    it "includes common credential field names" do
      expected_keys = %i[api_key access_token auth_token bearer_token password secret
                         credential api_secret private_key]

      expect(described_class::SENSITIVE_KEYS).to match_array(expected_keys)
    end

    it "is frozen" do
      expect(described_class::SENSITIVE_KEYS).to be_frozen
    end
  end

  describe "NON_SERIALIZABLE_KEYS" do
    it "includes client and logger" do
      expect(described_class::NON_SERIALIZABLE_KEYS).to include(:client, :logger)
    end

    it "includes model_id and kwargs" do
      expect(described_class::NON_SERIALIZABLE_KEYS).to include(:model_id, :kwargs)
    end

    it "is frozen" do
      expect(described_class::NON_SERIALIZABLE_KEYS).to be_frozen
    end
  end

  describe "ALLOWED_CLASSES" do
    it "is a frozen set" do
      expect(described_class::ALLOWED_CLASSES).to be_frozen
      expect(described_class::ALLOWED_CLASSES).to be_a(Set)
    end

    it "includes OpenAIModel, AnthropicModel, and LiteLLMModel" do
      expect(described_class::ALLOWED_CLASSES).to include(
        "Smolagents::OpenAIModel",
        "Smolagents::AnthropicModel",
        "Smolagents::LiteLLMModel"
      )
    end
  end

  describe "LOCAL_PROVIDERS" do
    it "includes local inference providers" do
      expect(described_class::LOCAL_PROVIDERS).to include(
        :lm_studio, :ollama, :llama_cpp, :mlx_lm, :vllm, :text_generation_webui
      )
    end

    it "is frozen" do
      expect(described_class::LOCAL_PROVIDERS).to be_frozen
    end
  end

  describe "ENV_KEYS" do
    it "maps providers to environment variable names" do
      expect(described_class::ENV_KEYS[:openai]).to eq("OPENAI_API_KEY")
      expect(described_class::ENV_KEYS[:anthropic]).to eq("ANTHROPIC_API_KEY")
      expect(described_class::ENV_KEYS[:azure]).to eq("AZURE_OPENAI_API_KEY")
      expect(described_class::ENV_KEYS[:gemini]).to eq("GOOGLE_API_KEY")
    end
  end

  describe "PROVIDER_METHODS" do
    it "maps local providers to factory methods" do
      expect(described_class::PROVIDER_METHODS[:lm_studio]).to eq(:lm_studio)
      expect(described_class::PROVIDER_METHODS[:ollama]).to eq(:ollama)
      expect(described_class::PROVIDER_METHODS[:llama_cpp]).to eq(:llama_cpp)
      expect(described_class::PROVIDER_METHODS[:vllm]).to eq(:vllm)
    end
  end

  describe ".detect_provider" do
    let(:model) { Smolagents::Model.new(model_id: "test") }

    it "uses provider from config when present" do
      config = { provider: "custom_provider" }

      result = described_class.detect_provider(model, config)

      expect(result).to eq(:custom_provider)
    end

    it "detects from api_base URL when no provider specified" do
      config = { api_base: "http://localhost:1234/v1" }

      result = described_class.detect_provider(model, config)

      expect(result).to eq(:lm_studio)
    end

    it "detects from uri_base URL" do
      config = { uri_base: "http://localhost:11434/v1" }

      result = described_class.detect_provider(model, config)

      expect(result).to eq(:ollama)
    end

    it "falls back to class-based detection" do
      result = described_class.detect_provider(model, {})

      expect(result).to eq(:openai)
    end
  end

  describe ".detect_from_url" do
    it "detects lm_studio from localhost:1234" do
      expect(described_class.detect_from_url("http://localhost:1234/v1")).to eq(:lm_studio)
    end

    it "detects lm_studio from lm.studio domain" do
      expect(described_class.detect_from_url("https://api.lm.studio/v1")).to eq(:lm_studio)
    end

    it "detects ollama from localhost:11434" do
      expect(described_class.detect_from_url("http://localhost:11434/api")).to eq(:ollama)
    end

    it "detects ollama from ollama domain" do
      expect(described_class.detect_from_url("http://ollama.local/api")).to eq(:ollama)
    end

    it "detects llama_cpp from localhost:8080" do
      expect(described_class.detect_from_url("http://localhost:8080/v1")).to eq(:llama_cpp)
    end

    it "detects vllm from localhost:8000" do
      expect(described_class.detect_from_url("http://localhost:8000/v1")).to eq(:vllm)
    end

    it "detects vllm from vllm domain" do
      expect(described_class.detect_from_url("http://vllm.example.com/v1")).to eq(:vllm)
    end

    it "detects azure from azure.com URL" do
      expect(described_class.detect_from_url("https://test.openai.azure.com/v1")).to eq(:azure)
    end

    it "defaults to openai for unknown URLs" do
      expect(described_class.detect_from_url("https://api.example.com/v1")).to eq(:openai)
    end
  end

  describe ".detect_from_class" do
    it "detects anthropic from AnthropicModel" do
      model = double(class: double(name: "Smolagents::AnthropicModel"))

      expect(described_class.detect_from_class(model)).to eq(:anthropic)
    end

    it "detects litellm provider from LiteLLMModel" do
      model = double(
        class: double(name: "Smolagents::LiteLLMModel"),
        respond_to?: true,
        provider: :ollama
      )

      expect(described_class.detect_from_class(model)).to eq(:ollama)
    end

    it "defaults to openai for unknown model types" do
      model = double(class: double(name: "SomeOtherModel"))

      expect(described_class.detect_from_class(model)).to eq(:openai)
    end
  end

  describe ".detect_litellm_provider" do
    it "returns model.provider when available" do
      model = double(respond_to?: true, provider: :ollama)

      expect(described_class.detect_litellm_provider(model)).to eq(:ollama)
    end

    it "returns openai when model does not respond to provider" do
      model = double(respond_to?: false)

      expect(described_class.detect_litellm_provider(model)).to eq(:openai)
    end

    it "returns openai when provider is nil" do
      model = double(respond_to?: true, provider: nil)

      expect(described_class.detect_litellm_provider(model)).to eq(:openai)
    end
  end
end
