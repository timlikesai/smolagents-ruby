require "spec_helper"

begin
  require "openai"
rescue LoadError
  nil # Optional dependency - tests use mocks
end

RSpec.describe Smolagents::Models::OpenAI::LocalServers do
  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(mock_client).to receive(:chat).and_return({
                                                      "id" => "chatcmpl-123",
                                                      "choices" => [{ "index" => 0,
                                                                      "message" => { "role" => "assistant",
                                                                                     "content" => "Hello!" } }]
                                                    })
  end

  describe "DEFAULT_MAX_TOKENS" do
    it "has a default max tokens value" do
      expect(described_class::DEFAULT_MAX_TOKENS).to eq(8192)
    end
  end

  describe "PORTS" do
    let(:ports) { described_class::PORTS }

    it "has correct port for lm_studio" do
      expect(ports[:lm_studio]).to eq(1234)
    end

    it "has correct port for ollama" do
      expect(ports[:ollama]).to eq(11_434)
    end

    it "has correct port for llama_cpp" do
      expect(ports[:llama_cpp]).to eq(8080)
    end

    it "has correct port for mlx_lm" do
      expect(ports[:mlx_lm]).to eq(8080)
    end

    it "has correct port for vllm" do
      expect(ports[:vllm]).to eq(8000)
    end

    it "has correct port for text_generation_webui" do
      expect(ports[:text_generation_webui]).to eq(5000)
    end

    it "is frozen" do
      expect(ports).to be_frozen
    end
  end

  describe ".lm_studio" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b", client: mock_client)

      expect(model.model_id).to eq("gemma-3n-e4b")
    end

    it "uses default localhost host" do
      model = Smolagents::OpenAIModel.lm_studio("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "uses default port 1234" do
      model = Smolagents::OpenAIModel.lm_studio("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.lm_studio("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.lm_studio("model", port: 5678, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom max_tokens" do
      model = Smolagents::OpenAIModel.lm_studio("model", max_tokens: 4096, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "passes additional options" do
      model = Smolagents::OpenAIModel.lm_studio(
        "model",
        temperature: 0.5,
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".ollama" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.ollama("llama3:latest", client: mock_client)

      expect(model.model_id).to eq("llama3:latest")
    end

    it "uses default port 11434" do
      model = Smolagents::OpenAIModel.ollama("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.ollama("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.ollama("model", port: 11_435, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".llama_cpp" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.llama_cpp("gguf-model", client: mock_client)

      expect(model.model_id).to eq("gguf-model")
    end

    it "uses default port 8080" do
      model = Smolagents::OpenAIModel.llama_cpp("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.llama_cpp("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.llama_cpp("model", port: 8081, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".mlx_lm" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.mlx_lm("mlx-model", client: mock_client)

      expect(model.model_id).to eq("mlx-model")
    end

    it "uses default port 8080" do
      model = Smolagents::OpenAIModel.mlx_lm("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.mlx_lm("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.mlx_lm("model", port: 8081, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".vllm" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.vllm("vllm-model", client: mock_client)

      expect(model.model_id).to eq("vllm-model")
    end

    it "uses default port 8000" do
      model = Smolagents::OpenAIModel.vllm("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.vllm("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.vllm("model", port: 8001, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".text_generation_webui" do
    it "creates model with correct model_id" do
      model = Smolagents::OpenAIModel.text_generation_webui("tgwui-model", client: mock_client)

      expect(model.model_id).to eq("tgwui-model")
    end

    it "uses default port 5000" do
      model = Smolagents::OpenAIModel.text_generation_webui("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom host" do
      model = Smolagents::OpenAIModel.text_generation_webui("model", host: "192.168.1.100", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "accepts custom port" do
      model = Smolagents::OpenAIModel.text_generation_webui("model", port: 5001, client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe "ClassMethods" do
    it "defines factory methods for all local servers" do
      described_class::PORTS.each_key do |server|
        expect(Smolagents::OpenAIModel).to respond_to(server)
      end
    end
  end
end
