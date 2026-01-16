require "smolagents"

RSpec.describe Smolagents::LiteLLMModel do
  describe "#initialize" do
    context "with provider prefixes" do
      it "parses openai/ prefix" do
        model = described_class.new(model_id: "openai/gpt-4")
        expect(model.provider).to eq("openai")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "parses anthropic/ prefix" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return("test-key")
        model = described_class.new(model_id: "anthropic/claude-3-opus")
        expect(model.provider).to eq("anthropic")
        expect(model.backend).to be_a(Smolagents::AnthropicModel)
      end

      it "defaults to openai for unknown prefixes" do
        model = described_class.new(model_id: "gpt-4o")
        expect(model.provider).to eq("openai")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "defaults to openai for model ids with slashes but unknown provider" do
        model = described_class.new(model_id: "org/gpt-4-custom")
        expect(model.provider).to eq("openai")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end
    end

    context "with local server prefixes" do
      it "routes ollama/ to OpenAI ollama factory" do
        model = described_class.new(model_id: "ollama/llama2")
        expect(model.provider).to eq("ollama")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "routes lm_studio/ to OpenAI lm_studio factory" do
        model = described_class.new(model_id: "lm_studio/local-model")
        expect(model.provider).to eq("lm_studio")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "routes llama_cpp/ to OpenAI llama_cpp factory" do
        model = described_class.new(model_id: "llama_cpp/model")
        expect(model.provider).to eq("llama_cpp")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "routes mlx_lm/ to OpenAI mlx_lm factory" do
        model = described_class.new(model_id: "mlx_lm/model")
        expect(model.provider).to eq("mlx_lm")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "routes vllm/ to OpenAI vllm factory" do
        model = described_class.new(model_id: "vllm/model")
        expect(model.provider).to eq("vllm")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end
    end

    context "with azure/ prefix" do
      it "creates an Azure-configured OpenAI backend" do
        model = described_class.new(
          model_id: "azure/gpt-4",
          api_base: "https://myresource.openai.azure.com",
          api_key: "test-key"
        )
        expect(model.provider).to eq("azure")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end

      it "uses AZURE_OPENAI_API_KEY env var if api_key not provided" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("AZURE_OPENAI_API_KEY", nil).and_return("env-key")
        model = described_class.new(
          model_id: "azure/gpt-4",
          api_base: "https://myresource.openai.azure.com"
        )
        expect(model.provider).to eq("azure")
      end

      it "accepts custom api_version" do
        model = described_class.new(
          model_id: "azure/gpt-4",
          api_base: "https://myresource.openai.azure.com",
          api_key: "test-key",
          api_version: "2023-12-01-preview"
        )
        expect(model.provider).to eq("azure")
        expect(model.backend).to be_a(Smolagents::OpenAIModel)
      end
    end
  end

  describe "delegation" do
    let(:backend) { instance_double(Smolagents::OpenAIModel) }
    let(:model) { described_class.new(model_id: "gpt-4") }

    before do
      allow(Smolagents::OpenAIModel).to receive(:new).and_return(backend)
    end

    it "delegates generate to backend" do
      messages = [Smolagents::ChatMessage.user("test")]
      allow(backend).to receive(:generate).with(messages, foo: "bar")
      model.generate(messages, foo: "bar")
      expect(backend).to have_received(:generate).with(messages, foo: "bar")
    end

    it "delegates generate_stream to backend" do
      messages = [Smolagents::ChatMessage.user("test")]
      allow(backend).to receive(:generate_stream).with(messages, foo: "bar")
      model.generate_stream(messages, foo: "bar")
      expect(backend).to have_received(:generate_stream).with(messages, foo: "bar")
    end
  end
end
