require "spec_helper"

begin
  require "openai"
rescue LoadError
  nil # Optional dependency - tests use mocks
end

RSpec.describe Smolagents::Models::OpenAI::CloudProviders do
  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(mock_client).to receive(:chat).and_return({
                                                      "id" => "chatcmpl-123",
                                                      "choices" => [{ "index" => 0,
                                                                      "message" => { "role" => "assistant",
                                                                                     "content" => "Hello!" } }]
                                                    })
  end

  describe "PROVIDERS" do
    let(:providers) { described_class::PROVIDERS }

    it "includes openrouter configuration" do
      expect(providers[:openrouter]).to eq({
                                             endpoint: "https://openrouter.ai/api/v1",
                                             env_var: "OPENROUTER_API_KEY"
                                           })
    end

    it "includes together configuration" do
      expect(providers[:together]).to eq({
                                           endpoint: "https://api.together.xyz/v1",
                                           env_var: "TOGETHER_API_KEY"
                                         })
    end

    it "includes groq configuration" do
      expect(providers[:groq]).to eq({
                                       endpoint: "https://api.groq.com/openai/v1",
                                       env_var: "GROQ_API_KEY"
                                     })
    end

    it "includes fireworks configuration" do
      expect(providers[:fireworks]).to eq({
                                            endpoint: "https://api.fireworks.ai/inference/v1",
                                            env_var: "FIREWORKS_API_KEY"
                                          })
    end

    it "includes deepinfra configuration" do
      expect(providers[:deepinfra]).to eq({
                                            endpoint: "https://api.deepinfra.com/v1/openai",
                                            env_var: "DEEPINFRA_API_KEY"
                                          })
    end

    it "is frozen" do
      expect(providers).to be_frozen
    end
  end

  describe ".openrouter" do
    it "creates model with correct model_id" do
      ENV["OPENROUTER_API_KEY"] = "test-key"
      model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet", client: mock_client)

      expect(model.model_id).to eq("anthropic/claude-3.5-sonnet")
      ENV.delete("OPENROUTER_API_KEY")
    end

    it "uses OPENROUTER_API_KEY env var by default" do
      ENV["OPENROUTER_API_KEY"] = "env-openrouter-key"
      model = Smolagents::OpenAIModel.openrouter("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
      ENV.delete("OPENROUTER_API_KEY")
    end

    it "accepts explicit api_key" do
      model = Smolagents::OpenAIModel.openrouter(
        "model",
        api_key: "explicit-key",
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end

    it "passes additional options" do
      model = Smolagents::OpenAIModel.openrouter(
        "model",
        api_key: "key",
        temperature: 0.5,
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".together" do
    it "creates model with correct model_id" do
      ENV["TOGETHER_API_KEY"] = "test-key"
      model = Smolagents::OpenAIModel.together("meta-llama/Llama-3.3-70B", client: mock_client)

      expect(model.model_id).to eq("meta-llama/Llama-3.3-70B")
      ENV.delete("TOGETHER_API_KEY")
    end

    it "uses TOGETHER_API_KEY env var by default" do
      ENV["TOGETHER_API_KEY"] = "env-together-key"
      model = Smolagents::OpenAIModel.together("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
      ENV.delete("TOGETHER_API_KEY")
    end

    it "accepts explicit api_key" do
      model = Smolagents::OpenAIModel.together(
        "model",
        api_key: "explicit-key",
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".groq" do
    it "creates model with correct model_id" do
      ENV["GROQ_API_KEY"] = "test-key"
      model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile", client: mock_client)

      expect(model.model_id).to eq("llama-3.3-70b-versatile")
      ENV.delete("GROQ_API_KEY")
    end

    it "uses GROQ_API_KEY env var by default" do
      ENV["GROQ_API_KEY"] = "env-groq-key"
      model = Smolagents::OpenAIModel.groq("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
      ENV.delete("GROQ_API_KEY")
    end

    it "accepts explicit api_key" do
      model = Smolagents::OpenAIModel.groq(
        "model",
        api_key: "explicit-key",
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".fireworks" do
    it "creates model with correct model_id" do
      ENV["FIREWORKS_API_KEY"] = "test-key"
      model = Smolagents::OpenAIModel.fireworks("accounts/fireworks/models/llama", client: mock_client)

      expect(model.model_id).to eq("accounts/fireworks/models/llama")
      ENV.delete("FIREWORKS_API_KEY")
    end

    it "uses FIREWORKS_API_KEY env var by default" do
      ENV["FIREWORKS_API_KEY"] = "env-fireworks-key"
      model = Smolagents::OpenAIModel.fireworks("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
      ENV.delete("FIREWORKS_API_KEY")
    end

    it "accepts explicit api_key" do
      model = Smolagents::OpenAIModel.fireworks(
        "model",
        api_key: "explicit-key",
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe ".deepinfra" do
    it "creates model with correct model_id" do
      ENV["DEEPINFRA_API_KEY"] = "test-key"
      model = Smolagents::OpenAIModel.deepinfra("meta-llama/Meta-Llama-3.1-70B", client: mock_client)

      expect(model.model_id).to eq("meta-llama/Meta-Llama-3.1-70B")
      ENV.delete("DEEPINFRA_API_KEY")
    end

    it "uses DEEPINFRA_API_KEY env var by default" do
      ENV["DEEPINFRA_API_KEY"] = "env-deepinfra-key"
      model = Smolagents::OpenAIModel.deepinfra("model", client: mock_client)

      expect(model).to be_a(Smolagents::OpenAIModel)
      ENV.delete("DEEPINFRA_API_KEY")
    end

    it "accepts explicit api_key" do
      model = Smolagents::OpenAIModel.deepinfra(
        "model",
        api_key: "explicit-key",
        client: mock_client
      )

      expect(model).to be_a(Smolagents::OpenAIModel)
    end
  end

  describe "ClassMethods" do
    it "defines factory methods for all providers" do
      described_class::PROVIDERS.each_key do |provider|
        expect(Smolagents::OpenAIModel).to respond_to(provider)
      end
    end
  end
end
