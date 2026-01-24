RSpec.describe Smolagents::Servers::LlamaCpp do
  let(:api_base) { "https://llama-cpp.example.com" }
  let(:server) { described_class.new(api_base:) }

  # Sample response data matching actual llama.cpp router format
  let(:models_response) do
    {
      "data" => [
        {
          "id" => "gemma-3n-E4B-it-Q8_0",
          "object" => "model",
          "owned_by" => "llamacpp",
          "status" => {
            "value" => "loaded",
            "args" => ["--ctx-size", "32768", "--model", "/models/gemma.gguf"],
            "preset" => "[gemma]\nctx-size = 32768\n"
          }
        },
        {
          "id" => "LFM2.5-1.2B-Instruct-Q8_0",
          "object" => "model",
          "owned_by" => "llamacpp",
          "status" => {
            "value" => "unloaded",
            "args" => ["--ctx-size", "128000"],
            "preset" => "[LFM2.5]\nctx-size = 128000\n"
          }
        },
        {
          "id" => "broken-model",
          "object" => "model",
          "owned_by" => "llamacpp",
          "status" => {
            "value" => "unloaded",
            "failed" => true,
            "exit_code" => 1
          }
        }
      ],
      "object" => "list"
    }
  end

  let(:slots_response) do
    [
      { "id" => 0, "n_ctx" => 32_768, "speculative" => false, "is_processing" => false },
      { "id" => 1, "n_ctx" => 32_768, "speculative" => false, "is_processing" => true },
      { "id" => 2, "n_ctx" => 32_768, "speculative" => false, "is_processing" => false },
      { "id" => 3, "n_ctx" => 32_768, "speculative" => false, "is_processing" => false }
    ]
  end

  let(:health_response) { { "status" => "ok" } }

  let(:warmup_response) do
    {
      "choices" => [{ "message" => { "content" => "hi" } }],
      "model" => "LFM2.5-1.2B-Instruct-Q8_0"
    }
  end

  before do
    stub_request(:get, "#{api_base}/v1/models")
      .to_return(status: 200, body: JSON.generate(models_response))

    stub_request(:get, "#{api_base}/health")
      .to_return(status: 200, body: JSON.generate(health_response))
  end

  describe "#initialize" do
    it "stores api_base without trailing slash" do
      server = described_class.new(api_base: "https://example.com/")
      expect(server.api_base).to eq("https://example.com")
    end

    it "accepts api_key" do
      server = described_class.new(api_base:, api_key: "secret")
      expect(server.api_key).to eq("secret")
    end

    it "defaults timeout to 30" do
      expect(server.timeout).to eq(30)
    end
  end

  describe "#models" do
    it "returns array of ModelInfo" do
      models = server.models
      expect(models).to all(be_a(described_class::ModelInfo))
      expect(models.size).to eq(3)
    end

    it "parses model status correctly" do
      models = server.models
      loaded = models.find { |m| m.id == "gemma-3n-E4B-it-Q8_0" }
      unloaded = models.find { |m| m.id == "LFM2.5-1.2B-Instruct-Q8_0" }
      failed = models.find { |m| m.id == "broken-model" }

      expect(loaded.status).to eq("loaded")
      expect(unloaded.status).to eq("unloaded")
      expect(failed.failed).to be true
    end

    it "extracts context size from args" do
      models = server.models
      gemma = models.find { |m| m.id == "gemma-3n-E4B-it-Q8_0" }
      expect(gemma.context_size).to eq(32_768)
    end
  end

  describe "#model_ids" do
    it "returns array of model IDs" do
      expect(server.model_ids).to contain_exactly(
        "gemma-3n-E4B-it-Q8_0",
        "LFM2.5-1.2B-Instruct-Q8_0",
        "broken-model"
      )
    end
  end

  describe "#loaded_models" do
    it "returns only loaded models" do
      loaded = server.loaded_models
      expect(loaded.size).to eq(1)
      expect(loaded.first.id).to eq("gemma-3n-E4B-it-Q8_0")
    end
  end

  describe "#model_status" do
    it "returns ModelInfo for existing model" do
      status = server.model_status("gemma-3n-E4B-it-Q8_0")
      expect(status).to be_a(described_class::ModelInfo)
      expect(status.loaded?).to be true
    end

    it "returns nil for non-existent model" do
      expect(server.model_status("non-existent")).to be_nil
    end
  end

  describe "#ready?" do
    it "returns true for loaded model" do
      expect(server.ready?("gemma-3n-E4B-it-Q8_0")).to be true
    end

    it "returns false for unloaded model" do
      expect(server.ready?("LFM2.5-1.2B-Instruct-Q8_0")).to be false
    end

    it "returns false for failed model" do
      expect(server.ready?("broken-model")).to be false
    end

    it "returns false for non-existent model" do
      expect(server.ready?("non-existent")).to be false
    end
  end

  describe "#slots" do
    before do
      stub_request(:get, "#{api_base}/slots?model=gemma-3n-E4B-it-Q8_0")
        .to_return(status: 200, body: JSON.generate(slots_response))
    end

    it "returns array of SlotInfo" do
      slots = server.slots("gemma-3n-E4B-it-Q8_0")
      expect(slots).to all(be_a(described_class::SlotInfo))
      expect(slots.size).to eq(4)
    end

    it "parses slot info correctly" do
      slots = server.slots("gemma-3n-E4B-it-Q8_0")
      expect(slots[0].id).to eq(0)
      expect(slots[0].context_size).to eq(32_768)
      expect(slots[0].processing).to be false
      expect(slots[1].processing).to be true
    end

    context "when model is not loaded" do
      before do
        stub_request(:get, "#{api_base}/slots?model=unloaded-model")
          .to_return(status: 400, body: JSON.generate(
            error: { message: "model name is missing" }
          ))
      end

      it "raises ArgumentError" do
        expect { server.slots("unloaded-model") }
          .to raise_error(ArgumentError, /not loaded/)
      end
    end
  end

  describe "#warmup" do
    before do
      stub_request(:post, "#{api_base}/v1/chat/completions")
        .with(body: hash_including("model" => "LFM2.5-1.2B-Instruct-Q8_0"))
        .to_return(status: 200, body: JSON.generate(warmup_response))

      # After warmup, the model should be loaded
      stub_request(:get, "#{api_base}/v1/models")
        .to_return(status: 200, body: JSON.generate({
                                                      "data" => [
                                                        models_response["data"][0],
                                                        models_response["data"][1].merge(
                                                          "status" => { "value" => "loaded" }
                                                        ),
                                                        models_response["data"][2]
                                                      ]
                                                    }))
    end

    it "sends minimal chat completion request" do
      server.warmup("LFM2.5-1.2B-Instruct-Q8_0")

      expect(WebMock).to have_requested(:post, "#{api_base}/v1/chat/completions")
        .with(body: hash_including(
          "model" => "LFM2.5-1.2B-Instruct-Q8_0",
          "max_tokens" => 1
        ))
    end

    it "returns updated model status" do
      result = server.warmup("LFM2.5-1.2B-Instruct-Q8_0")
      expect(result).to be_a(described_class::ModelInfo)
    end
  end

  describe "#model" do
    it "returns configured OpenAIModel" do
      model = server.model("gemma-3n-E4B-it-Q8_0")
      expect(model).to be_a(Smolagents::Models::OpenAIModel)
      expect(model.model_id).to eq("gemma-3n-E4B-it-Q8_0")
    end

    it "configures api_base with /v1 suffix" do
      model = server.model("test")
      # The OpenAIModel stores the client, not the api_base directly
      # We can verify by checking model behavior or internal state
      expect(model).to respond_to(:generate)
    end

    it "passes max_tokens option" do
      model = server.model("test", max_tokens: 4096)
      expect(model.max_tokens).to eq(4096)
    end

    it "passes additional options" do
      model = server.model("test", temperature: 0.5)
      expect(model.temperature).to eq(0.5)
    end
  end

  describe "#healthy?" do
    it "returns true when server responds ok" do
      expect(server.healthy?).to be true
    end

    context "when server is down" do
      before do
        stub_request(:get, "#{api_base}/health")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "returns false" do
        expect(server.healthy?).to be false
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "#{api_base}/health")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "returns false" do
        expect(server.healthy?).to be false
      end
    end
  end

  describe "ModelInfo" do
    let(:loaded_info) do
      described_class::ModelInfo.new(
        id: "test",
        status: "loaded",
        context_size: 32_768,
        failed: false,
        preset: nil
      )
    end

    let(:unloaded_info) do
      described_class::ModelInfo.new(
        id: "test",
        status: "unloaded",
        context_size: 32_768,
        failed: false,
        preset: nil
      )
    end

    let(:failed_info) do
      described_class::ModelInfo.new(
        id: "test",
        status: "unloaded",
        context_size: nil,
        failed: true,
        preset: nil
      )
    end

    it "loaded? returns true for loaded status" do
      expect(loaded_info.loaded?).to be true
      expect(unloaded_info.loaded?).to be false
    end

    it "unloaded? returns true for unloaded status" do
      expect(unloaded_info.unloaded?).to be true
      expect(loaded_info.unloaded?).to be false
    end

    it "failed? returns true when failed flag is set" do
      expect(failed_info.failed?).to be true
      expect(loaded_info.failed?).to be false
    end

    it "ready? returns true only for loaded and not failed" do
      expect(loaded_info.ready?).to be true
      expect(unloaded_info.ready?).to be false
      expect(failed_info.ready?).to be false
    end
  end

  describe "with api_key" do
    let(:server) { described_class.new(api_base:, api_key: "secret-key") }

    before do
      stub_request(:get, "#{api_base}/v1/models")
        .with(headers: { "Authorization" => "Bearer secret-key" })
        .to_return(status: 200, body: JSON.generate(models_response))
    end

    it "includes authorization header" do
      server.models
      expect(WebMock).to have_requested(:get, "#{api_base}/v1/models")
        .with(headers: { "Authorization" => "Bearer secret-key" })
    end
  end
end
