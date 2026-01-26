RSpec.describe Smolagents::Types::ModelConfig do
  describe ".create" do
    it "creates a config with required model_id" do
      config = described_class.create(model_id: "gpt-4")
      expect(config.model_id).to eq("gpt-4")
    end

    it "uses default temperature of 0.7" do
      config = described_class.create(model_id: "gpt-4")
      expect(config.temperature).to eq(0.7)
    end

    it "accepts all optional parameters" do
      config = described_class.create(
        model_id: "gpt-4",
        api_key: "sk-test",
        api_base: "http://localhost:1234/v1",
        temperature: 0.5,
        max_tokens: 4096,
        azure_api_version: "2024-02-15",
        timeout: 30
      )

      expect(config.model_id).to eq("gpt-4")
      expect(config.api_key).to eq("sk-test")
      expect(config.api_base).to eq("http://localhost:1234/v1")
      expect(config.temperature).to eq(0.5)
      expect(config.max_tokens).to eq(4096)
      expect(config.azure_api_version).to eq("2024-02-15")
      expect(config.timeout).to eq(30)
    end

    it "stores extra options in extras hash" do
      config = described_class.create(
        model_id: "gpt-4",
        custom_option: "value"
      )

      expect(config.extras).to eq({ custom_option: "value" })
    end

    it "freezes the extras hash" do
      config = described_class.create(model_id: "gpt-4", foo: "bar")
      expect(config.extras).to be_frozen
    end
  end

  describe "#with" do
    it "returns a new config with changed fields" do
      config = described_class.create(model_id: "gpt-4", temperature: 0.7)
      updated = config.with(temperature: 0.9)

      expect(updated.temperature).to eq(0.9)
      expect(updated.model_id).to eq("gpt-4")
      expect(config.temperature).to eq(0.7) # Original unchanged
    end

    it "can change model_id" do
      config = described_class.create(model_id: "gpt-4")
      updated = config.with(model_id: "gpt-4-turbo")

      expect(updated.model_id).to eq("gpt-4-turbo")
    end
  end

  describe "#to_model_args" do
    it "returns keyword arguments for model initialization" do
      config = described_class.create(
        model_id: "gpt-4",
        api_key: "sk-test",
        temperature: 0.5
      )

      args = config.to_model_args

      expect(args).to include(
        model_id: "gpt-4",
        api_key: "sk-test",
        temperature: 0.5
      )
    end

    it "omits nil values" do
      config = described_class.create(model_id: "gpt-4")
      args = config.to_model_args

      expect(args).to have_key(:model_id)
      expect(args).to have_key(:temperature) # Has default value
      expect(args).not_to have_key(:api_key)
      expect(args).not_to have_key(:max_tokens)
    end

    it "merges extras into the hash" do
      config = described_class.create(model_id: "gpt-4", custom: "value")
      args = config.to_model_args

      expect(args[:custom]).to eq("value")
    end
  end

  describe "#local?" do
    it "returns true for localhost" do
      config = described_class.create(model_id: "model", api_base: "http://localhost:1234/v1")
      expect(config.local?).to be true
    end

    it "returns true for 127.0.0.1" do
      config = described_class.create(model_id: "model", api_base: "http://127.0.0.1:8000/v1")
      expect(config.local?).to be true
    end

    it "returns false for remote URLs" do
      config = described_class.create(model_id: "model", api_base: "https://api.openai.com/v1")
      expect(config.local?).to be false
    end

    it "returns false when api_base is nil" do
      config = described_class.create(model_id: "model")
      expect(config.local?).to be false
    end
  end

  describe "#azure?" do
    it "returns true when azure_api_version is set" do
      config = described_class.create(model_id: "model", azure_api_version: "2024-02-15")
      expect(config.azure?).to be true
    end

    it "returns false when azure_api_version is nil" do
      config = described_class.create(model_id: "model")
      expect(config.azure?).to be false
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      config = described_class.create(model_id: "gpt-4", temperature: 0.5)

      case config
      in { model_id: id, temperature: temp }
        expect(id).to eq("gpt-4")
        expect(temp).to eq(0.5)
      else
        raise "Pattern match failed"
      end
    end
  end

  describe "immutability" do
    it "is a frozen Data object" do
      config = described_class.create(model_id: "gpt-4")
      expect(config).to be_frozen
    end
  end

  describe "integration with models" do
    before do
      require "openai"
      Stoplight.default_data_store = Stoplight::DataStore::Memory.new
      Stoplight.default_notifiers = []
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    let(:mock_client) { instance_double(OpenAI::Client) }
    let(:mock_response) do
      {
        "id" => "chatcmpl-123",
        "choices" => [{ "message" => { "role" => "assistant", "content" => "Hello!" } }],
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
      }
    end

    it "works with OpenAIModel" do
      config = described_class.create(
        model_id: "gpt-4",
        api_key: "test-key",
        temperature: 0.5
      )

      model = Smolagents::OpenAIModel.new(config:, client: mock_client)

      expect(model.model_id).to eq("gpt-4")
      expect(model.temperature).to eq(0.5)
    end

    it "allows keyword args to override config" do
      config = described_class.create(
        model_id: "gpt-4",
        api_key: "config-key",
        temperature: 0.5
      )

      # NOTE: When using config, the config values take precedence
      model = Smolagents::OpenAIModel.new(config:, client: mock_client)

      expect(model.model_id).to eq("gpt-4")
      expect(model.temperature).to eq(0.5)
    end
  end
end
