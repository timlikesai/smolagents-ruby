# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe Smolagents::DefaultTools do
  describe Smolagents::DefaultTools::FinalAnswerTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("final_answer")
      expect(tool.description).to include("final answer")
      expect(tool.output_type).to eq("any")
    end

    it "raises FinalAnswerException when called" do
      expect {
        tool.call(answer: "42")
      }.to raise_error(Smolagents::FinalAnswerException) do |error|
        expect(error.value).to eq("42")
      end
    end
  end

  describe Smolagents::DefaultTools::WebSearchTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("web_search")
      expect(tool.description).to include("web")
      expect(tool.output_type).to eq("string")
    end

    it "performs web search with DuckDuckGo" do
      # Stub HTTP request to DuckDuckGo
      stub_request(:get, "https://lite.duckduckgo.com/lite/")
        .with(query: hash_including("q" => "Ruby programming"))
        .to_return(
          status: 200,
          body: <<~HTML
            <html>
            <tr>
              <td><a class="result-link">Ruby Programming<span class="link-text">ruby-lang.org</span></a></td>
              <td class="result-snippet">Ruby is a dynamic language</td>
            </tr>
            </html>
          HTML
        )

      result = tool.call(query: "Ruby programming")
      expect(result).to include("## Search Results")
      expect(result).to include("Ruby Programming")
    end
  end

  describe Smolagents::DefaultTools::VisitWebpageTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("visit_webpage")
      expect(tool.description).to include("webpage")
      expect(tool.output_type).to eq("string")
    end

    it "fetches and converts webpage to markdown" do
      # Stub HTTP request
      stub_request(:get, "https://example.com")
        .to_return(
          status: 200,
          body: <<~HTML
            <html>
              <body>
                <h1>Example Domain</h1>
                <p>This domain is for use in examples.</p>
              </body>
            </html>
          HTML
        )

      result = tool.call(url: "https://example.com")
      expect(result).to include("Example Domain")
      expect(result).to include("This domain is for use in examples")
    end
  end

  describe ".get" do
    it "returns tool by name" do
      tool = described_class.get("final_answer")
      expect(tool).to be_a(Smolagents::DefaultTools::FinalAnswerTool)
    end

    it "returns nil for unknown tool" do
      expect(described_class.get("unknown")).to be_nil
    end
  end

  describe ".all" do
    it "returns all default tools" do
      # Some tools require API keys, so we'll check the mapping instead
      expect(described_class::TOOL_MAPPING.size).to eq(10)  # All 10 tools
      expect(described_class::TOOL_MAPPING.keys).to contain_exactly(
        "final_answer",
        "ruby_interpreter",
        "user_input",
        "web_search",
        "duckduckgo_search",
        "google_search",
        "api_web_search",
        "visit_webpage",
        "wikipedia_search",
        "transcriber"
      )
    end
  end
end
