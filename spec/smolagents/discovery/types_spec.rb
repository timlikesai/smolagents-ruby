require "smolagents"

RSpec.describe "Smolagents::Discovery types", type: :feature do
  describe Smolagents::Discovery::Result do
    let(:ready_model) do
      Smolagents::Discovery::DiscoveredModel.new(
        id: "llama-3.2", provider: :lm_studio, host: "localhost", port: 1234,
        context_length: 8192, state: :loaded, capabilities: ["tool_use"], type: "llm",
        tls: false, api_key: nil
      )
    end

    let(:unloaded_model) do
      Smolagents::Discovery::DiscoveredModel.new(
        id: "gpt-4", provider: :lm_studio, host: "localhost", port: 1234,
        context_length: nil, state: :not_loaded, capabilities: nil, type: nil,
        tls: false, api_key: nil
      )
    end

    let(:available_server) do
      Smolagents::Discovery::LocalServer.new(
        provider: :lm_studio, host: "localhost", port: 1234,
        models: [ready_model], error: nil
      )
    end

    let(:empty_server) do
      Smolagents::Discovery::LocalServer.new(
        provider: :ollama, host: "localhost", port: 11_434,
        models: [], error: nil
      )
    end

    let(:configured_provider) do
      Smolagents::Discovery::CloudProvider.new(
        provider: :openai, configured: true, env_var: "OPENAI_API_KEY"
      )
    end

    let(:unconfigured_provider) do
      Smolagents::Discovery::CloudProvider.new(
        provider: :anthropic, configured: false, env_var: "ANTHROPIC_API_KEY"
      )
    end

    describe "#any?" do
      it "returns true when local servers have available models" do
        result = described_class.new(
          local_servers: [available_server],
          cloud_providers: [unconfigured_provider],
          scanned_at: Time.now
        )

        expect(result.any?).to be true
      end

      it "returns true when cloud providers are configured" do
        result = described_class.new(
          local_servers: [empty_server],
          cloud_providers: [configured_provider],
          scanned_at: Time.now
        )

        expect(result.any?).to be true
      end

      it "returns false when no models or providers available" do
        result = described_class.new(
          local_servers: [empty_server],
          cloud_providers: [unconfigured_provider],
          scanned_at: Time.now
        )

        expect(result.any?).to be false
      end
    end

    describe "#all_models" do
      it "returns all models from all servers" do
        second_server = Smolagents::Discovery::LocalServer.new(
          provider: :ollama, host: "localhost", port: 11_434,
          models: [unloaded_model], error: nil
        )

        result = described_class.new(
          local_servers: [available_server, second_server],
          cloud_providers: [],
          scanned_at: Time.now
        )

        expect(result.all_models).to contain_exactly(ready_model, unloaded_model)
      end

      it "returns empty array when no servers" do
        result = described_class.new(
          local_servers: [],
          cloud_providers: [],
          scanned_at: Time.now
        )

        expect(result.all_models).to eq([])
      end
    end

    describe "#code_examples" do
      it "includes examples from ready models" do
        result = described_class.new(
          local_servers: [available_server],
          cloud_providers: [],
          scanned_at: Time.now
        )

        examples = result.code_examples
        expect(examples).not_to be_empty
        expect(examples.first).to include("llama-3.2")
      end

      it "includes examples from configured cloud providers" do
        result = described_class.new(
          local_servers: [],
          cloud_providers: [configured_provider],
          scanned_at: Time.now
        )

        examples = result.code_examples
        expect(examples).not_to be_empty
      end

      it "limits to 2 models per server and 2 cloud providers" do
        models = (1..5).map do |i|
          Smolagents::Discovery::DiscoveredModel.new(
            id: "model-#{i}", provider: :lm_studio, host: "localhost", port: 1234,
            context_length: 8192, state: :loaded, capabilities: nil, type: nil,
            tls: false, api_key: nil
          )
        end

        server = Smolagents::Discovery::LocalServer.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models:, error: nil
        )

        result = described_class.new(
          local_servers: [server],
          cloud_providers: [],
          scanned_at: Time.now
        )

        # Should only include first 2 ready models
        expect(result.code_examples.length).to eq(2)
      end
    end

    describe "#summary" do
      it "summarizes local models count" do
        result = described_class.new(
          local_servers: [available_server],
          cloud_providers: [],
          scanned_at: Time.now
        )

        expect(result.summary).to eq("1 local model")
      end

      it "summarizes cloud providers count" do
        result = described_class.new(
          local_servers: [],
          cloud_providers: [configured_provider],
          scanned_at: Time.now
        )

        expect(result.summary).to eq("1 cloud provider")
      end

      it "combines local and cloud summaries" do
        result = described_class.new(
          local_servers: [available_server],
          cloud_providers: [configured_provider],
          scanned_at: Time.now
        )

        expect(result.summary).to eq("1 local model, 1 cloud provider")
      end

      it "pluralizes correctly" do
        models = (1..3).map do |i|
          Smolagents::Discovery::DiscoveredModel.new(
            id: "model-#{i}", provider: :lm_studio, host: "localhost", port: 1234,
            context_length: 8192, state: :loaded, capabilities: nil, type: nil,
            tls: false, api_key: nil
          )
        end

        server = Smolagents::Discovery::LocalServer.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models:, error: nil
        )

        result = described_class.new(
          local_servers: [server],
          cloud_providers: [],
          scanned_at: Time.now
        )

        expect(result.summary).to eq("3 local models")
      end

      it "returns message when nothing discovered" do
        result = described_class.new(
          local_servers: [],
          cloud_providers: [unconfigured_provider],
          scanned_at: Time.now
        )

        expect(result.summary).to eq("No models discovered")
      end
    end
  end

  describe Smolagents::Discovery::LocalServer do
    describe "#available?" do
      it "returns true when server has models" do
        model = Smolagents::Discovery::DiscoveredModel.new(
          id: "test", provider: :lm_studio, host: "localhost", port: 1234,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: false, api_key: nil
        )

        server = described_class.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models: [model], error: nil
        )

        expect(server.available?).to be true
      end

      it "returns false when server has no models" do
        server = described_class.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models: [], error: nil
        )

        expect(server.available?).to be false
      end
    end

    describe "#name" do
      it "returns display name from config" do
        server = described_class.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models: [], error: nil
        )

        expect(server.name).to eq("LM Studio")
      end

      it "falls back to provider string for unknown providers" do
        server = described_class.new(
          provider: :unknown_provider, host: "localhost", port: 8000,
          models: [], error: nil
        )

        expect(server.name).to eq("unknown_provider")
      end
    end

    describe "#docs" do
      it "returns documentation URL from config" do
        server = described_class.new(
          provider: :ollama, host: "localhost", port: 11_434,
          models: [], error: nil
        )

        expect(server.docs).to eq("https://ollama.ai/docs")
      end
    end

    describe "#base_url" do
      it "constructs HTTP URL from host and port" do
        server = described_class.new(
          provider: :lm_studio, host: "localhost", port: 1234,
          models: [], error: nil
        )

        expect(server.base_url).to eq("http://localhost:1234")
      end
    end
  end

  describe Smolagents::Discovery::DiscoveredModel do
    let(:loaded_model) do
      described_class.new(
        id: "llama-3", provider: :lm_studio, host: "localhost", port: 1234,
        context_length: 8192, state: :loaded, capabilities: %w[tool_use vision],
        type: "vlm", tls: false, api_key: nil
      )
    end

    let(:unloaded_model) do
      described_class.new(
        id: "mistral", provider: :ollama, host: "localhost", port: 11_434,
        context_length: nil, state: :not_loaded, capabilities: nil, type: nil,
        tls: false, api_key: nil
      )
    end

    describe "#ready?" do
      it "returns true for loaded state" do
        expect(loaded_model.ready?).to be true
      end

      it "returns true for available state" do
        model = described_class.new(
          id: "test", provider: :lm_studio, host: "localhost", port: 1234,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: false, api_key: nil
        )

        expect(model.ready?).to be true
      end

      it "returns false for not_loaded state" do
        expect(unloaded_model.ready?).to be false
      end
    end

    describe "#tool_use?" do
      it "returns true when capabilities include tool_use" do
        expect(loaded_model.tool_use?).to be true
      end

      it "returns false when capabilities do not include tool_use" do
        model = described_class.new(
          id: "test", provider: :lm_studio, host: "localhost", port: 1234,
          context_length: nil, state: :loaded, capabilities: ["vision"], type: nil,
          tls: false, api_key: nil
        )

        expect(model.tool_use?).to be false
      end

      it "returns falsy when capabilities is nil" do
        expect(unloaded_model).not_to be_tool_use
      end
    end

    describe "#vision?" do
      it "returns true for vlm type" do
        expect(loaded_model.vision?).to be true
      end

      it "returns true when capabilities include vision" do
        model = described_class.new(
          id: "test", provider: :lm_studio, host: "localhost", port: 1234,
          context_length: nil, state: :loaded, capabilities: ["vision"], type: "llm",
          tls: false, api_key: nil
        )

        expect(model.vision?).to be true
      end

      it "returns falsy when not vlm and no vision capability" do
        expect(unloaded_model).not_to be_vision
      end
    end

    describe "#base_url" do
      it "constructs HTTP URL for non-TLS" do
        expect(loaded_model.base_url).to eq("http://localhost:1234")
      end

      it "constructs HTTPS URL for TLS" do
        model = described_class.new(
          id: "test", provider: :openai_compatible, host: "api.example.com", port: 443,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: true, api_key: "sk-123"
        )

        expect(model.base_url).to eq("https://api.example.com:443")
      end
    end

    describe "#localhost?" do
      it "returns true for localhost" do
        expect(loaded_model.localhost?).to be true
      end

      it "returns true for 127.0.0.1" do
        model = described_class.new(
          id: "test", provider: :lm_studio, host: "127.0.0.1", port: 1234,
          context_length: nil, state: :loaded, capabilities: nil, type: nil,
          tls: false, api_key: nil
        )

        expect(model.localhost?).to be true
      end

      it "returns false for remote hosts" do
        model = described_class.new(
          id: "test", provider: :openai_compatible, host: "api.example.com", port: 443,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: true, api_key: nil
        )

        expect(model.localhost?).to be false
      end
    end

    describe "#code_example" do
      it "generates factory method example for localhost with known provider" do
        example = loaded_model.code_example

        expect(example).to include("OpenAIModel.lm_studio")
        expect(example).to include("llama-3")
        expect(example).to include("8K context")
      end

      it "includes not loaded note for unready models" do
        model = described_class.new(
          id: "test", provider: :lm_studio, host: "localhost", port: 1234,
          context_length: nil, state: :not_loaded, capabilities: nil, type: nil,
          tls: false, api_key: nil
        )

        expect(model.code_example).to include("(not loaded)")
      end

      it "generates explicit URL example for remote servers" do
        model = described_class.new(
          id: "llama-3", provider: :openai_compatible, host: "remote.example.com", port: 8080,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: false, api_key: nil
        )

        example = model.code_example

        expect(example).to include("OpenAIModel.new")
        expect(example).to include("api_base:")
        expect(example).to include("http://remote.example.com:8080/v1")
      end

      it "includes api_key parameter for authenticated servers" do
        model = described_class.new(
          id: "test", provider: :openai_compatible, host: "remote.example.com", port: 443,
          context_length: nil, state: :available, capabilities: nil, type: nil,
          tls: true, api_key: "sk-123"
        )

        example = model.code_example

        expect(example).to include('api_key: "sk-123"')
      end
    end
  end

  describe Smolagents::Discovery::CloudProvider do
    describe "#configured?" do
      it "returns true when configured" do
        provider = described_class.new(
          provider: :openai, configured: true, env_var: "OPENAI_API_KEY"
        )

        expect(provider.configured?).to be true
      end

      it "returns false when not configured" do
        provider = described_class.new(
          provider: :openai, configured: false, env_var: "OPENAI_API_KEY"
        )

        expect(provider.configured?).to be false
      end
    end

    describe "#name" do
      it "returns display name from config" do
        provider = described_class.new(
          provider: :anthropic, configured: true, env_var: "ANTHROPIC_API_KEY"
        )

        expect(provider.name).to eq("Anthropic")
      end
    end

    describe "#docs" do
      it "returns documentation URL from config" do
        provider = described_class.new(
          provider: :openai, configured: true, env_var: "OPENAI_API_KEY"
        )

        expect(provider.docs).to eq("https://platform.openai.com/docs")
      end
    end

    describe "#code_example" do
      it "returns code example for the provider" do
        provider = described_class.new(
          provider: :openai, configured: true, env_var: "OPENAI_API_KEY"
        )

        expect(provider.code_example).to include("gpt-4-turbo")
      end

      it "returns nil for unknown providers" do
        provider = described_class.new(
          provider: :unknown, configured: true, env_var: "UNKNOWN_API_KEY"
        )

        expect(provider.code_example).to be_nil
      end
    end
  end
end
