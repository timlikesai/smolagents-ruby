# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe Smolagents::Tools do
  describe Smolagents::FinalAnswerTool do
    subject(:tool) { described_class.new }

    it "has correct configuration" do
      expect(tool.name).to eq("final_answer")
      expect(tool.description).to include("final answer")
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
      stub_request(:get, "https://lite.duckduckgo.com/lite/")
        .with(query: hash_including("q" => "Ruby"))
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
      expect(Smolagents::Tools.get("final_answer")).to be_a(Smolagents::FinalAnswerTool)
    end

    it "returns nil for unknown" do
      expect(Smolagents::Tools.get("unknown")).to be_nil
    end
  end

  describe ".names" do
    it "lists all tool names" do
      expect(Smolagents::Tools.names).to contain_exactly(
        "final_answer", "ruby_interpreter", "user_input",
        "duckduckgo_search", "bing_search", "brave_search",
        "google_search", "wikipedia_search", "visit_webpage", "speech_to_text"
      )
    end
  end
end
