# frozen_string_literal: true

require "webmock/rspec"
require "tempfile"

RSpec.describe "Tools Comprehensive Tests" do
  describe Smolagents::GoogleSearchTool do
    context "with SerpAPI" do
      subject(:tool) { described_class.new(provider: "serpapi", api_key: "test_key") }

      it "performs search" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("q" => "Ruby", "api_key" => "test_key"))
          .to_return(status: 200, body: JSON.generate({
            "organic_results" => [{ "title" => "Ruby Lang", "link" => "https://ruby-lang.org", "snippet" => "Dynamic" }]
          }))

        result = tool.call(query: "Ruby")
        expect(result).to include("Ruby Lang")
      end

      it "handles year filtering" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("tbs" => "cdr:1,cd_min:01/01/2023,cd_max:12/31/2023"))
          .to_return(status: 200, body: JSON.generate({
            "organic_results" => [{ "title" => "Result", "link" => "https://example.com", "snippet" => "Text" }]
          }))

        result = tool.call(query: "test", filter_year: 2023)
        expect(result).to include("Result")
      end

      it "handles empty results" do
        stub_request(:get, %r{serpapi\.com/search\.json})
          .to_return(status: 200, body: JSON.generate({ "organic_results" => [] }))

        result = tool.call(query: "test")
        expect(result).to include("No results found")
      end
    end

    context "with Serper" do
      subject(:tool) { described_class.new(provider: "serper", api_key: "test_key") }

      it "uses correct endpoint" do
        stub_request(:get, %r{google\.serper\.dev/search})
          .to_return(status: 200, body: JSON.generate({
            "organic" => [{ "title" => "Test", "link" => "https://test.com", "snippet" => "Test" }]
          }))

        result = tool.call(query: "test")
        expect(result).to include("Test")
      end
    end

    it "requires API key" do
      expect { described_class.new(provider: "serpapi") }.to raise_error(ArgumentError, /Missing API key/)
    end
  end

  describe Smolagents::BraveSearchTool do
    subject(:tool) { described_class.new(api_key: "test_key") }

    it "performs search" do
      stub_request(:get, %r{api\.search\.brave\.com/res/v1/web/search})
        .with(headers: { "X-Subscription-Token" => "test_key" })
        .to_return(status: 200, body: JSON.generate({
          "web" => { "results" => [
            { "title" => "AI Guide", "url" => "https://example.com/ai", "description" => "Learn AI" }
          ]}
        }))

      result = tool.call(query: "AI")
      expect(result).to include("AI Guide")
    end

    it "handles empty results" do
      stub_request(:get, %r{api\.search\.brave\.com/res/v1/web/search})
        .to_return(status: 200, body: JSON.generate({ "web" => { "results" => [] } }))

      result = tool.call(query: "test")
      expect(result).to eq("No results found.")
    end

    it "enforces rate limiting" do
      stub_request(:get, %r{api\.search\.brave\.com/res/v1/web/search})
        .to_return(status: 200, body: JSON.generate({ "web" => { "results" => [] } }))

      start = Time.now
      tool.call(query: "test1")
      tool.call(query: "test2")
      elapsed = Time.now - start

      expect(elapsed).to be >= 0.9 # rate_limit 1.0
    end
  end

  describe Smolagents::SpeechToTextTool do
    context "with OpenAI" do
      subject(:tool) { described_class.new(provider: "openai", api_key: "test_key") }

      it "transcribes audio" do
        audio_file = Tempfile.new(["test", ".mp3"])
        audio_file.write("fake audio")
        audio_file.rewind

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 200, body: JSON.generate({ "text" => "Hello world" }))

        result = tool.call(audio: audio_file.path)
        expect(result).to eq("Hello world")

        audio_file.close
        audio_file.unlink
      end
    end

    it "requires API key" do
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return(nil)
      expect { described_class.new(provider: "openai") }.to raise_error(ArgumentError, /Missing API key/)
    end
  end

  describe Smolagents::BingSearchTool do
    subject(:tool) { described_class.new }

    it "parses RSS results" do
      stub_request(:get, "https://www.bing.com/search")
        .with(query: hash_including("q" => "Ruby", "format" => "rss"))
        .to_return(status: 200, body: <<~XML)
          <?xml version="1.0"?>
          <rss><channel>
            <item>
              <title>Ruby Lang</title>
              <link>https://ruby-lang.org</link>
              <description>Dynamic language</description>
            </item>
          </channel></rss>
        XML

      result = tool.call(query: "Ruby")
      expect(result).to include("Ruby Lang")
    end
  end
end
