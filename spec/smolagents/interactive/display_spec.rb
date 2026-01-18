RSpec.describe Smolagents::Interactive::Display do
  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  let(:model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "test-model",
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

  let(:server) do
    Smolagents::Discovery::LocalServer.new(
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      models: [model],
      error: nil
    )
  end

  let(:cloud_provider) do
    Smolagents::Discovery::CloudProvider.new(
      provider: :openai,
      configured: true,
      env_var: "OPENAI_API_KEY"
    )
  end

  let(:discovery) do
    Smolagents::Discovery::Result.new(
      local_servers: [server],
      cloud_providers: [cloud_provider],
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

  describe ".header" do
    it "returns colored header with title" do
      header = described_class.header
      expect(header).to include("smolagents")
    end

    it "includes version when defined" do
      stub_const("Smolagents::VERSION", "1.0.0")
      header = described_class.header
      expect(header).to include("v1.0.0")
    end

    it "applies bold and bright cyan styling" do
      header = described_class.header
      expect(header).to include("\e[1m")
      expect(header).to include("\e[96m")
    end
  end

  describe ".getting_started" do
    it "outputs getting started information" do
      expect { described_class.getting_started }.to output(/No models found/).to_stdout
    end

    it "mentions LM Studio" do
      expect { described_class.getting_started }.to output(/LM Studio/).to_stdout
    end

    it "mentions cloud API keys" do
      expect { described_class.getting_started }.to output(/OPENAI_API_KEY/).to_stdout
    end
  end

  describe ".local_getting_started" do
    it "outputs local server instructions" do
      expect { described_class.local_getting_started }.to output(/Local Models/).to_stdout
    end

    it "mentions LM Studio download" do
      expect { described_class.local_getting_started }.to output(/lmstudio.ai/).to_stdout
    end
  end

  describe ".cloud_getting_started" do
    it "outputs cloud API instructions" do
      expect { described_class.cloud_getting_started }.to output(/Cloud APIs/).to_stdout
    end

    it "shows environment variable examples" do
      output = capture_stdout { described_class.cloud_getting_started }
      expect(output).to include("OPENAI_API_KEY")
      expect(output).to include("OPENROUTER_API_KEY")
      expect(output).to include("GROQ_API_KEY")
    end
  end

  describe ".models_section" do
    it "outputs models for available servers" do
      expect { described_class.models_section(discovery) }.to output(/LM Studio/).to_stdout
    end

    it "outputs nothing for unavailable servers" do
      unavailable_server = server.with(models: [])
      unavailable_discovery = discovery.with(local_servers: [unavailable_server])
      expect { described_class.models_section(unavailable_discovery) }.not_to output.to_stdout
    end
  end

  describe ".search_section" do
    before do
      allow(Smolagents::Interactive::Suggestions).to receive(:current_search_provider).and_return(nil)
    end

    it "outputs nothing when no custom search provider" do
      expect { described_class.search_section }.not_to output.to_stdout
    end

    context "with SearXNG configured" do
      let(:searxng_provider) do
        { provider: :searxng, name: "SearXNG", url: "https://search.example.com" }
      end

      before do
        allow(Smolagents::Interactive::Suggestions)
          .to receive(:current_search_provider).and_return(searxng_provider)
      end

      it "outputs search section" do
        expect { described_class.search_section }.to output(/Search/).to_stdout
      end

      it "shows SearXNG with host" do
        expect { described_class.search_section }.to output(/SearXNG.*search\.example\.com/).to_stdout
      end
    end

    context "with other search provider" do
      let(:brave_provider) do
        { provider: :brave, name: "Brave Search", url: nil }
      end

      before do
        allow(Smolagents::Interactive::Suggestions)
          .to receive(:current_search_provider).and_return(brave_provider)
      end

      it "outputs provider name" do
        expect { described_class.search_section }.to output(/Brave Search/).to_stdout
      end
    end
  end

  describe ".search_line" do
    it "formats SearXNG with host extraction" do
      info = { provider: :searxng, url: "https://search.example.com/search" }
      line = described_class.search_line(info)
      expect(line).to include("SearXNG")
      expect(line).to include("search.example.com")
    end

    it "handles SearXNG without URL" do
      info = { provider: :searxng, url: nil }
      line = described_class.search_line(info)
      expect(line).to include("configured")
    end

    it "formats other providers" do
      info = { provider: :brave, name: "Brave Search" }
      line = described_class.search_line(info)
      expect(line).to include("Brave Search")
    end
  end

  describe ".cloud_section" do
    it "outputs cloud providers when configured" do
      expect { described_class.cloud_section(discovery) }.to output(/Cloud APIs/).to_stdout
    end

    it "shows configured provider with env var" do
      output = capture_stdout { described_class.cloud_section(discovery) }
      expect(output).to include("OPENAI_API_KEY")
    end

    it "outputs nothing when no cloud providers configured" do
      unconfigured = discovery.with(cloud_providers: [])
      expect { described_class.cloud_section(unconfigured) }.not_to output.to_stdout
    end
  end

  describe ".try_it_section" do
    before do
      suggestion = Smolagents::Interactive::Suggestions::Suggestion.new(
        model:,
        question: "Test question?",
        search_provider: nil
      )
      allow(Smolagents::Interactive::Suggestions).to receive(:generate).and_return(suggestion)
    end

    it "outputs try it section" do
      expect { described_class.try_it_section(discovery) }.to output(/Try it/).to_stdout
    end

    it "includes code example" do
      expect { described_class.try_it_section(discovery) }.to output(/Smolagents\.agent/).to_stdout
    end

    it "outputs nothing when no suggestion" do
      allow(Smolagents::Interactive::Suggestions).to receive(:generate).and_return(nil)
      expect { described_class.try_it_section(discovery) }.not_to output.to_stdout
    end
  end

  describe ".models_list" do
    it "shows getting started when empty" do
      expect { described_class.models_list(empty_discovery) }.to output(/No models found/).to_stdout
    end

    it "shows servers with models" do
      expect { described_class.models_list(discovery) }.to output(/LM Studio/).to_stdout
    end

    it "shows filter hint for non-all filter" do
      expect { described_class.models_list(discovery, filter: :ready) }.to output(/ready models/).to_stdout
    end

    it "does not show filter hint for all filter" do
      expect { described_class.models_list(discovery, filter: :all) }.not_to output(/Showing/).to_stdout
    end
  end

  describe ".empty_discovery?" do
    it "returns true when no models and no cloud providers" do
      expect(described_class.empty_discovery?(empty_discovery)).to be true
    end

    it "returns false when models exist" do
      expect(described_class.empty_discovery?(discovery)).to be false
    end

    it "returns false when cloud provider configured" do
      with_cloud = empty_discovery.with(cloud_providers: [cloud_provider])
      expect(described_class.empty_discovery?(with_cloud)).to be false
    end
  end

  describe ".show_filter_hint" do
    it "outputs nothing for :all filter" do
      expect { described_class.show_filter_hint(:all) }.not_to output.to_stdout
    end

    it "outputs hint for :ready filter" do
      expect { described_class.show_filter_hint(:ready) }.to output(/ready models/).to_stdout
    end

    it "outputs hint for custom filter" do
      expect { described_class.show_filter_hint(:loaded) }.to output(/loaded models/).to_stdout
    end
  end

  describe ".show_filtered_servers" do
    it "shows server with matching models" do
      expect { described_class.show_filtered_servers(discovery, :ready) }.to output(/LM Studio/).to_stdout
    end

    it "skips servers with no matching models" do
      unloaded = model.with(state: :unloaded)
      srv = server.with(models: [unloaded])
      disc = discovery.with(local_servers: [srv])
      expect { described_class.show_filtered_servers(disc, :ready) }.not_to output(/LM Studio/).to_stdout
    end
  end

  describe ".show_cloud_list" do
    it "shows configured cloud providers" do
      expect { described_class.show_cloud_list(discovery) }.to output(/Cloud Providers/).to_stdout
    end

    it "outputs nothing when no cloud providers" do
      expect { described_class.show_cloud_list(empty_discovery) }.not_to output.to_stdout
    end

    it "shows code example for provider" do
      output = capture_stdout { described_class.show_cloud_list(discovery) }
      expect(output).to include("openai") if output.include?("openai")
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
