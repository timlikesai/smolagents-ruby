require "smolagents"

RSpec.describe "Smolagents::Discovery configuration constants", type: :feature do
  describe "LOCAL_SERVERS" do
    subject(:local_servers) { Smolagents::Discovery::LOCAL_SERVERS }

    it "is frozen" do
      expect(local_servers).to be_frozen
    end

    it "includes lm_studio configuration" do
      expect(local_servers[:lm_studio]).to include(
        name: "LM Studio",
        ports: [1234]
      )
      expect(local_servers[:lm_studio][:api_v1_path]).to eq("/api/v1/models")
      expect(local_servers[:lm_studio][:v0_path]).to eq("/api/v0/models")
      expect(local_servers[:lm_studio][:v1_path]).to eq("/v1/models")
    end

    it "includes ollama configuration" do
      expect(local_servers[:ollama]).to include(
        name: "Ollama",
        ports: [11_434]
      )
      expect(local_servers[:ollama][:api_path]).to eq("/api/tags")
    end

    it "includes llama_cpp configuration" do
      expect(local_servers[:llama_cpp]).to include(
        name: "llama.cpp",
        ports: [8080]
      )
    end

    it "includes vllm configuration" do
      expect(local_servers[:vllm]).to include(
        name: "vLLM",
        ports: [8000]
      )
    end

    it "includes mlx_lm configuration" do
      expect(local_servers[:mlx_lm]).to include(
        name: "MLX-LM",
        ports: [8080]
      )
    end

    it "includes openai_compatible as fallback" do
      expect(local_servers[:openai_compatible]).to include(
        name: "OpenAI-compatible",
        ports: []
      )
    end

    it "provides docs URL for each server" do
      local_servers.each do |provider, config|
        expect(config[:docs]).to be_a(String), "#{provider} should have docs URL"
        expect(config[:docs]).to start_with("https://")
      end
    end

    it "provides at least one API path for each server" do
      local_servers.each do |provider, config|
        paths = %i[v1_path v0_path api_v1_path api_path]
        has_path = paths.any? { |p| config[p] }
        expect(has_path).to be(true), "#{provider} should have at least one API path"
      end
    end
  end

  describe "CLOUD_PROVIDERS" do
    subject(:cloud_providers) { Smolagents::Discovery::CLOUD_PROVIDERS }

    it "is frozen" do
      expect(cloud_providers).to be_frozen
    end

    it "includes openai configuration" do
      expect(cloud_providers[:openai]).to eq(
        name: "OpenAI",
        env_var: "OPENAI_API_KEY",
        docs: "https://platform.openai.com/docs"
      )
    end

    it "includes anthropic configuration" do
      expect(cloud_providers[:anthropic]).to eq(
        name: "Anthropic",
        env_var: "ANTHROPIC_API_KEY",
        docs: "https://docs.anthropic.com"
      )
    end

    it "includes openrouter configuration" do
      expect(cloud_providers[:openrouter]).to include(
        name: "OpenRouter",
        env_var: "OPENROUTER_API_KEY"
      )
    end

    it "includes groq configuration" do
      expect(cloud_providers[:groq]).to include(
        name: "Groq",
        env_var: "GROQ_API_KEY"
      )
    end

    it "includes together configuration" do
      expect(cloud_providers[:together]).to include(
        name: "Together AI",
        env_var: "TOGETHER_API_KEY"
      )
    end

    it "includes fireworks configuration" do
      expect(cloud_providers[:fireworks]).to include(
        name: "Fireworks AI",
        env_var: "FIREWORKS_API_KEY"
      )
    end

    it "includes deepinfra configuration" do
      expect(cloud_providers[:deepinfra]).to include(
        name: "DeepInfra",
        env_var: "DEEPINFRA_API_KEY"
      )
    end

    it "provides env_var for each provider" do
      cloud_providers.each do |provider, config|
        expect(config[:env_var]).to be_a(String), "#{provider} should have env_var"
        expect(config[:env_var]).to end_with("_API_KEY")
      end
    end

    it "provides docs URL for each provider" do
      cloud_providers.each do |provider, config|
        expect(config[:docs]).to be_a(String), "#{provider} should have docs URL"
        expect(config[:docs]).to start_with("https://")
      end
    end
  end

  describe "CLOUD_CODE_EXAMPLES" do
    subject(:examples) { Smolagents::Discovery::CLOUD_CODE_EXAMPLES }

    it "is frozen" do
      expect(examples).to be_frozen
    end

    it "provides examples for all cloud providers" do
      Smolagents::Discovery::CLOUD_PROVIDERS.each_key do |provider|
        expect(examples[provider]).to be_a(String), "#{provider} should have code example"
      end
    end

    it "includes OpenAIModel for openai" do
      expect(examples[:openai]).to include("OpenAIModel.new")
      expect(examples[:openai]).to include("gpt-4-turbo")
    end

    it "includes AnthropicModel for anthropic" do
      expect(examples[:anthropic]).to include("AnthropicModel.new")
      expect(examples[:anthropic]).to include("claude")
    end

    it "uses factory methods for cloud provider endpoints" do
      expect(examples[:openrouter]).to include("OpenAIModel.openrouter")
      expect(examples[:groq]).to include("OpenAIModel.groq")
      expect(examples[:together]).to include("OpenAIModel.together")
      expect(examples[:fireworks]).to include("OpenAIModel.fireworks")
      expect(examples[:deepinfra]).to include("OpenAIModel.deepinfra")
    end

    it "includes model IDs in examples" do
      examples.each do |provider, example|
        # Each example should include a model name/ID
        expect(example).to match(%r{"\w+[\w\-/.]+"}), "#{provider} example should include model ID"
      end
    end
  end
end
