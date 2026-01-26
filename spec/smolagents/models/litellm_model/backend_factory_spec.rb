require "spec_helper"

RSpec.describe Smolagents::Models::LiteLLM::BackendFactory do
  # Create a test class that includes the module to test private methods
  let(:test_class) do
    Class.new do
      include Smolagents::Models::LiteLLM::ProviderRouting
      include Smolagents::Models::LiteLLM::BackendFactory

      # Expose private methods for testing
      public :create_backend, :create_openai_backend, :create_azure_backend
    end
  end

  let(:factory) { test_class.new }

  describe "AZURE_API_VERSION" do
    it "has a default Azure API version" do
      expect(Smolagents::Models::LiteLLM::BackendFactory::AZURE_API_VERSION).to eq("2024-02-15-preview")
    end
  end

  describe "#create_backend" do
    context "with anthropic provider" do
      it "creates an AnthropicModel" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return("test-key")

        backend = factory.create_backend("anthropic", "claude-3-opus", api_key: "test-key")

        expect(backend).to be_a(Smolagents::AnthropicModel)
      end
    end

    context "with azure provider" do
      it "creates an Azure-configured OpenAIModel" do
        backend = factory.create_backend(
          "azure", "gpt-4",
          api_base: "https://myresource.openai.azure.com",
          api_key: "test-key"
        )

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end
    end

    context "with openai provider" do
      it "creates a standard OpenAIModel" do
        backend = factory.create_backend("openai", "gpt-4", api_key: "test-key")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end
    end

    context "with local server provider" do
      it "creates OpenAIModel via lm_studio factory" do
        backend = factory.create_backend("lm_studio", "local-model")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end

      it "creates OpenAIModel via ollama factory" do
        backend = factory.create_backend("ollama", "llama2")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end

      it "creates OpenAIModel via llama_cpp factory" do
        backend = factory.create_backend("llama_cpp", "model")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end

      it "creates OpenAIModel via mlx_lm factory" do
        backend = factory.create_backend("mlx_lm", "model")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end

      it "creates OpenAIModel via vllm factory" do
        backend = factory.create_backend("vllm", "model")

        expect(backend).to be_a(Smolagents::OpenAIModel)
      end
    end
  end

  describe "#create_openai_backend" do
    context "with non-local provider" do
      it "creates a generic OpenAIModel" do
        backend = factory.create_openai_backend("openai", "gpt-4", api_key: "test-key")

        expect(backend).to be_a(Smolagents::OpenAIModel)
        expect(backend.model_id).to eq("gpt-4")
      end
    end

    context "with local server provider" do
      it "uses the appropriate factory method for lm_studio" do
        backend = factory.create_openai_backend("lm_studio", "local-model")

        expect(backend).to be_a(Smolagents::OpenAIModel)
        expect(backend.model_id).to eq("local-model")
      end

      it "uses the appropriate factory method for ollama" do
        backend = factory.create_openai_backend("ollama", "llama2")

        expect(backend).to be_a(Smolagents::OpenAIModel)
        expect(backend.model_id).to eq("llama2")
      end
    end
  end

  describe "#create_azure_backend" do
    it "creates OpenAIModel with Azure-specific configuration" do
      backend = factory.create_azure_backend(
        "gpt-4-deployment",
        api_base: "https://myresource.openai.azure.com",
        api_key: "azure-key"
      )

      expect(backend).to be_a(Smolagents::OpenAIModel)
      expect(backend.model_id).to eq("gpt-4-deployment")
    end

    it "strips trailing slash from api_base" do
      backend = factory.create_azure_backend(
        "gpt-4",
        api_base: "https://myresource.openai.azure.com/",
        api_key: "test-key"
      )

      expect(backend).to be_a(Smolagents::OpenAIModel)
    end

    it "uses AZURE_OPENAI_API_KEY env var when api_key not provided" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("AZURE_OPENAI_API_KEY", nil).and_return("env-azure-key")

      backend = factory.create_azure_backend(
        "gpt-4",
        api_base: "https://myresource.openai.azure.com"
      )

      expect(backend).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom api_version" do
      backend = factory.create_azure_backend(
        "gpt-4",
        api_base: "https://myresource.openai.azure.com",
        api_key: "test-key",
        api_version: "2023-12-01-preview"
      )

      expect(backend).to be_a(Smolagents::OpenAIModel)
    end

    it "uses default api_version when not specified" do
      backend = factory.create_azure_backend(
        "gpt-4",
        api_base: "https://myresource.openai.azure.com",
        api_key: "test-key"
      )

      expect(backend).to be_a(Smolagents::OpenAIModel)
    end
  end
end
