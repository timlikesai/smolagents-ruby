require "webmock/rspec"

RSpec.describe Smolagents::Tools do
  describe Smolagents::FinalAnswerTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("final_answer")
      expect(tool.description).to include("end the task")
      expect(tool.output_type).to eq("any")
    end

    it "raises FinalAnswerException when called" do
      expect { tool.call(answer: "42") }.to raise_error(Smolagents::FinalAnswerException) { |e| expect(e.value).to eq("42") }
    end
  end

  describe Smolagents::DuckDuckGoSearchTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("duckduckgo_search")
      expect(tool.output_type).to eq("string")
    end

    it "performs search" do
      stub_request(:post, "https://lite.duckduckgo.com/lite/")
        .with(body: hash_including("q" => "Ruby"))
        .to_return(status: 200, body: <<~HTML)
          <html><tr>
            <td><a class="result-link">Ruby Lang<span class="link-text">ruby-lang.org</span></a></td>
            <td class="result-snippet">A dynamic language</td>
          </tr></html>
        HTML

      result = tool.call(query: "Ruby")
      expect(result).to include("Ruby Lang")
    end
  end

  describe Smolagents::VisitWebpageTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("visit_webpage")
      expect(tool.output_type).to eq("string")
    end

    it "fetches webpage and converts to markdown" do
      stub_request(:get, "https://example.com")
        .to_return(status: 200, body: "<html><body><h1>Test</h1><p>Content</p></body></html>")

      result = tool.call(url: "https://example.com")
      expect(result).to include("Test")
      expect(result).to include("Content")
    end
  end

  describe ".get" do
    it "returns tool by name" do
      expect(described_class.get("final_answer")).to be_a(Smolagents::FinalAnswerTool)
    end

    it "returns nil for unknown" do
      expect(described_class.get("unknown")).to be_nil
    end

    context "with web_search" do
      after { Smolagents.reset_configuration! }

      it "resolves to duckduckgo by default" do
        tool = described_class.get("web_search")
        expect(tool).to be_a(Smolagents::DuckDuckGoSearchTool)
      end

      it "resolves to configured provider" do
        Smolagents.configure { |c| c.search_provider = :bing }
        tool = described_class.get("web_search")
        expect(tool).to be_a(Smolagents::BingSearchTool)
      end
    end
  end

  describe ".names" do
    it "lists all tool lookup keys including web_search alias" do
      expect(described_class.names).to contain_exactly(
        "final_answer", "ruby_interpreter", "user_input",
        "duckduckgo_search", "bing_search", "brave_search",
        "google_search", "wikipedia_search", "searxng_search",
        "visit_webpage", "speech_to_text", "web_search"
      )
    end
  end
end
