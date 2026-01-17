RSpec.describe Smolagents::Interactive::Suggestions do
  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  let(:model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "gemma-3n-e4b",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: 32_000,
      state: :loaded,
      capabilities: ["tool_use"],
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:remote_model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "remote-model",
      provider: :llama_cpp,
      host: "gpu-server.local",
      port: 8080,
      context_length: 16_000,
      state: :loaded,
      capabilities: nil,
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:server) do
    Smolagents::Discovery::LocalServer.new(
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      models: [model],
      error: nil
    )
  end

  let(:discovery) do
    Smolagents::Discovery::Result.new(
      local_servers: [server],
      cloud_providers: [],
      scanned_at: Time.now
    )
  end

  let(:empty_discovery) do
    Smolagents::Discovery::Result.new(
      local_servers: [],
      cloud_providers: [],
      scanned_at: Time.now
    )
  end

  describe "QUESTIONS" do
    it "contains question templates" do
      expect(described_class::QUESTIONS).to be_an(Array)
      expect(described_class::QUESTIONS).not_to be_empty
    end

    it "includes programming questions" do
      expect(described_class::QUESTIONS.any? { |q| q.include?("Ruby") }).to be true
    end

    it "is frozen" do
      expect(described_class::QUESTIONS).to be_frozen
    end
  end

  describe "data constants" do
    it "defines CITIES" do
      expect(described_class::CITIES).to include("Tokyo", "London", "Paris")
      expect(described_class::CITIES).to be_frozen
    end

    it "defines ANIMALS" do
      expect(described_class::ANIMALS).to include("octopus", "tardigrade", "capybara")
      expect(described_class::ANIMALS).to be_frozen
    end

    it "defines NOBEL_CATEGORIES" do
      expect(described_class::NOBEL_CATEGORIES).to include("Physics", "Chemistry", "Peace")
      expect(described_class::NOBEL_CATEGORIES).to be_frozen
    end
  end

  describe ".generate" do
    it "returns a Suggestion when models available" do
      result = described_class.generate(discovery)
      expect(result).to be_a(described_class::Suggestion)
    end

    it "returns nil when no models available" do
      result = described_class.generate(empty_discovery)
      expect(result).to be_nil
    end

    it "includes model in suggestion" do
      result = described_class.generate(discovery)
      expect(result.model).to eq(model)
    end

    it "includes a question" do
      result = described_class.generate(discovery)
      expect(result.question).to be_a(String)
      expect(result.question).not_to be_empty
    end

    it "includes search provider info" do
      result = described_class.generate(discovery)
      # By default should be nil (duckduckgo is default)
      expect(result.search_provider).to be_nil
    end

    context "with multiple models" do
      let(:long_name_model) do
        model.with(id: "very-long-model-name-that-should-be-deprioritized")
      end

      it "prefers local models over remote" do
        remote_server = server.with(
          host: "gpu-server.local",
          models: [remote_model]
        )
        mixed_discovery = discovery.with(local_servers: [server, remote_server])
        result = described_class.generate(mixed_discovery)
        expect(result.model.localhost?).to be true
      end

      it "prefers shorter model names" do
        multi_model_server = server.with(models: [long_name_model, model])
        multi_discovery = discovery.with(local_servers: [multi_model_server])
        result = described_class.generate(multi_discovery)
        expect(result.model.id).to eq("gemma-3n-e4b")
      end
    end

    context "with unloaded models only" do
      let(:unloaded_model) { model.with(state: :unloaded) }
      let(:unloaded_server) { server.with(models: [unloaded_model]) }
      let(:unloaded_discovery) { discovery.with(local_servers: [unloaded_server]) }

      it "returns nil" do
        result = described_class.generate(unloaded_discovery)
        expect(result).to be_nil
      end
    end
  end

  describe ".current_search_provider" do
    after { Smolagents.reset_configuration! }

    it "returns nil for default duckduckgo provider" do
      Smolagents.configure { |c| c.search_provider = :duckduckgo }
      expect(described_class.current_search_provider).to be_nil
    end

    it "returns provider info for searxng" do
      Smolagents.configure do |c|
        c.search_provider = :searxng
        c.searxng_url = "https://search.example.com"
      end
      result = described_class.current_search_provider
      expect(result[:provider]).to eq(:searxng)
      expect(result[:url]).to eq("https://search.example.com")
    end

    it "returns provider info for other providers" do
      Smolagents.configure { |c| c.search_provider = :brave }
      result = described_class.current_search_provider
      expect(result[:provider]).to eq(:brave)
      expect(result[:name]).to eq("Brave")
    end
  end

  describe "question interpolation" do
    it "interpolates placeholders in generated questions" do
      # Generate multiple questions to test interpolation
      # The question should not contain any uninterpolated placeholders
      10.times do
        result = described_class.generate(discovery)
        expect(result.question).not_to include("%<city>s")
        expect(result.question).not_to include("%<animal>s")
        expect(result.question).not_to include("%<nobel>s")
        expect(result.question).not_to include("%<year>s")
        expect(result.question).not_to include("%<ruby_version>s")
      end
    end

    it "returns non-empty question strings" do
      10.times do
        result = described_class.generate(discovery)
        expect(result.question).to be_a(String)
        expect(result.question.length).to be > 10
      end
    end
  end
end

RSpec.describe Smolagents::Interactive::Suggestions::Suggestion do
  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  let(:model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "gemma-3n-e4b",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: 32_000,
      state: :loaded,
      capabilities: ["tool_use"],
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:suggestion) do
    described_class.new(
      model:,
      question: "What is Ruby?",
      search_provider: nil
    )
  end

  let(:suggestion_with_searxng) do
    described_class.new(
      model:,
      question: "What is Ruby?",
      search_provider: { provider: :searxng, name: "SearXNG", url: "https://search.example.com" }
    )
  end

  let(:suggestion_with_brave) do
    described_class.new(
      model:,
      question: "What is Ruby?",
      search_provider: { provider: :brave, name: "Brave Search", url: nil }
    )
  end

  describe "#code" do
    it "returns valid Ruby code" do
      code = suggestion.code
      expect(code).to include("Smolagents.agent")
      expect(code).to include(".model {")
      expect(code).to include(".tools(:search)")
      expect(code).to include(".run(")
    end

    it "includes the question" do
      expect(suggestion.code).to include("What is Ruby?")
    end

    it "includes model code example" do
      expect(suggestion.code).to include("lm_studio")
      expect(suggestion.code).to include("gemma-3n-e4b")
    end

    it "includes event handlers" do
      expect(suggestion.code).to include(".on(:step)")
      expect(suggestion.code).to include(".on(:tool)")
    end

    it "includes output printing" do
      expect(suggestion.code).to include("puts result.output")
    end
  end

  describe "#custom_search?" do
    it "returns false when no search provider" do
      expect(suggestion.custom_search?).to be false
    end

    it "returns true when search provider configured" do
      expect(suggestion_with_searxng.custom_search?).to be true
    end
  end

  describe "#search_description" do
    it "returns default description when no custom provider" do
      expect(suggestion.search_description).to eq("DuckDuckGo + Wikipedia")
    end

    it "returns SearXNG description with host" do
      desc = suggestion_with_searxng.search_description
      expect(desc).to include("SearXNG")
      expect(desc).to include("search.example.com")
    end

    it "handles SearXNG without URL" do
      suggestion_no_url = described_class.new(
        model:,
        question: "test",
        search_provider: { provider: :searxng, name: "SearXNG", url: nil }
      )
      expect(suggestion_no_url.search_description).to include("your instance")
    end

    it "returns provider name for other providers" do
      expect(suggestion_with_brave.search_description).to eq("Brave Search")
    end
  end

  describe "Data.define behavior" do
    it "is immutable" do
      expect(suggestion).to be_frozen
    end

    it "has model accessor" do
      expect(suggestion.model).to eq(model)
    end

    it "has question accessor" do
      expect(suggestion.question).to eq("What is Ruby?")
    end

    it "has search_provider accessor" do
      expect(suggestion.search_provider).to be_nil
    end

    it "supports with for creating modified copies" do
      new_suggestion = suggestion.with(question: "New question?")
      expect(new_suggestion.question).to eq("New question?")
      expect(new_suggestion.model).to eq(model)
    end
  end
end
