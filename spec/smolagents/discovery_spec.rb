require "smolagents/discovery"

RSpec.describe Smolagents::Discovery do
  before do
    # Stub all local server requests to avoid real network calls
    stub_request(:get, /localhost:\d+/).to_return(status: 404, body: "")
    stub_request(:get, /127\.0\.0\.1:\d+/).to_return(status: 404, body: "")
  end

  describe "LOCAL_SERVERS" do
    it "includes known inference server configurations" do
      expect(described_class::LOCAL_SERVERS).to include(:lm_studio, :ollama, :llama_cpp, :vllm)
    end

    it "has correct default ports" do
      expect(described_class::LOCAL_SERVERS[:lm_studio][:ports]).to eq([1234])
      expect(described_class::LOCAL_SERVERS[:ollama][:ports]).to eq([11_434])
      expect(described_class::LOCAL_SERVERS[:llama_cpp][:ports]).to eq([8080])
      expect(described_class::LOCAL_SERVERS[:vllm][:ports]).to eq([8000])
    end
  end

  describe "CLOUD_PROVIDERS" do
    it "includes known cloud API providers" do
      expect(described_class::CLOUD_PROVIDERS).to include(:openai, :anthropic, :openrouter, :groq, :together)
    end

    it "has correct environment variable names" do
      expect(described_class::CLOUD_PROVIDERS[:openai][:env_var]).to eq("OPENAI_API_KEY")
      expect(described_class::CLOUD_PROVIDERS[:openrouter][:env_var]).to eq("OPENROUTER_API_KEY")
      expect(described_class::CLOUD_PROVIDERS[:groq][:env_var]).to eq("GROQ_API_KEY")
    end
  end

  describe Smolagents::Discovery::Result do
    let(:local_server) do
      Smolagents::Discovery::LocalServer.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        models: [model],
        error: nil
      )
    end

    let(:model) do
      Smolagents::Discovery::DiscoveredModel.new(
        id: "gemma-3n-e4b",
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        context_length: 32_768,
        state: :loaded,
        capabilities: ["tool_use"],
        type: "llm",
        tls: false,
        api_key: nil
      )
    end

    let(:cloud_provider) do
      Smolagents::Discovery::CloudProvider.new(
        provider: :openrouter,
        configured: true,
        env_var: "OPENROUTER_API_KEY"
      )
    end

    let(:result) do
      described_class.new(
        local_servers: [local_server],
        cloud_providers: [cloud_provider],
        scanned_at: Time.now
      )
    end

    describe "#any?" do
      it "returns true when local servers have models" do
        expect(result.any?).to be true
      end

      it "returns true when cloud providers are configured" do
        empty_result = described_class.new(
          local_servers: [],
          cloud_providers: [cloud_provider],
          scanned_at: Time.now
        )
        expect(empty_result.any?).to be true
      end

      it "returns false when nothing is available" do
        empty = described_class.new(
          local_servers: [],
          cloud_providers: [],
          scanned_at: Time.now
        )
        expect(empty.any?).to be false
      end
    end

    describe "#all_models" do
      it "returns models from all local servers" do
        expect(result.all_models).to eq([model])
      end
    end

    describe "#code_examples" do
      it "generates code examples for ready models" do
        examples = result.code_examples
        expect(examples).to be_an(Array)
        expect(examples.first).to include("OpenAIModel")
      end
    end

    describe "#summary" do
      it "provides a human-readable summary" do
        expect(result.summary).to include("local model")
        expect(result.summary).to include("cloud provider")
      end
    end
  end

  describe Smolagents::Discovery::DiscoveredModel do
    let(:model) do
      described_class.new(
        id: "llama-3.3-70b",
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        context_length: 131_072,
        state: :loaded,
        capabilities: ["tool_use"],
        type: "llm",
        tls: false,
        api_key: nil
      )
    end

    describe "#ready?" do
      it "returns true for loaded models" do
        expect(model.ready?).to be true
      end

      it "returns true for available models" do
        available = model.with(state: :available)
        expect(available.ready?).to be true
      end

      it "returns false for not_loaded models" do
        unloaded = model.with(state: :not_loaded)
        expect(unloaded.ready?).to be false
      end
    end

    describe "#tool_use?" do
      it "returns true when capabilities include tool_use" do
        expect(model.tool_use?).to be true
      end

      it "returns falsey when capabilities don't include tool_use" do
        no_tools = model.with(capabilities: nil)
        expect(no_tools).not_to be_tool_use
      end
    end

    describe "#vision?" do
      it "returns true for vlm type" do
        vlm = model.with(type: "vlm")
        expect(vlm.vision?).to be true
      end

      it "returns true when capabilities include vision" do
        vision = model.with(capabilities: ["vision"])
        expect(vision.vision?).to be true
      end

      it "returns false for regular llm type" do
        expect(model.vision?).to be false
      end
    end

    describe "#code_example" do
      it "generates valid Ruby code" do
        expect(model.code_example).to include("Smolagents::OpenAIModel.lm_studio")
        expect(model.code_example).to include(model.id)
      end

      it "includes context length comment" do
        expect(model.code_example).to include("131K context")
      end
    end

    describe "#base_url" do
      it "returns the server URL" do
        expect(model.base_url).to eq("http://localhost:1234")
      end
    end
  end

  describe Smolagents::Discovery::CloudProvider do
    let(:provider) do
      described_class.new(
        provider: :openrouter,
        configured: true,
        env_var: "OPENROUTER_API_KEY"
      )
    end

    describe "#configured?" do
      it "returns the configured status" do
        expect(provider.configured?).to be true
      end
    end

    describe "#name" do
      it "returns the provider name" do
        expect(provider.name).to eq("OpenRouter")
      end
    end

    describe "#code_example" do
      it "generates appropriate code for each provider" do
        expect(provider.code_example).to include("openrouter")
      end
    end
  end

  describe ".scan" do
    it "returns a Result" do
      result = described_class.scan(timeout: 0.1)
      expect(result).to be_a(Smolagents::Discovery::Result)
    end

    it "scans cloud providers without timeout" do
      result = described_class.scan(timeout: 0.1)
      expect(result.cloud_providers).to be_an(Array)
    end

    it "accepts custom endpoints" do
      stub_request(:get, /custom-server/).to_return(status: 404, body: "")

      result = described_class.scan(
        timeout: 0.1,
        custom_endpoints: [
          { provider: :llama_cpp, host: "custom-server", port: 8080 }
        ]
      )
      expect(result.local_servers).to be_an(Array)
    end
  end

  describe ".available?" do
    it "returns true when cloud API key is set" do
      ENV["OPENAI_API_KEY"] = "test-key"
      expect(described_class.available?).to be true
      ENV.delete("OPENAI_API_KEY")
    end

    it "returns false when no cloud keys and no local servers" do
      # Clear all known API keys
      keys = %w[OPENAI_API_KEY ANTHROPIC_API_KEY OPENROUTER_API_KEY GROQ_API_KEY TOGETHER_API_KEY]
      saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
      keys.each { |k| ENV.delete(k) }

      # NetworkStubs ensures all ports are closed by default
      expect(described_class.available?).to be false

      # Restore
      saved.each { |k, v| ENV[k] = v if v }
    end

    it "returns true when local server is running" do
      # Clear API keys
      keys = %w[OPENAI_API_KEY ANTHROPIC_API_KEY OPENROUTER_API_KEY GROQ_API_KEY TOGETHER_API_KEY]
      saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
      keys.each { |k| ENV.delete(k) }

      # Simulate LM Studio running on default port
      NetworkStubs.stub_port_open("localhost", 1234)
      expect(described_class.available?).to be true

      # Restore
      saved.each { |k, v| ENV[k] = v if v }
    end
  end
end
