require "webmock/rspec"
require "tempfile"

RSpec.describe Smolagents::Tools do
  describe Smolagents::GoogleSearchTool do
    subject(:tool) { described_class.new(api_key: "test_key", cse_id: "test_cse_id") }

    it "performs search" do
      body = { "items" => [{ "title" => "Ruby Lang", "link" => "https://ruby-lang.org", "snippet" => "Dynamic" }] }
      stub_request(:get, "https://www.googleapis.com/customsearch/v1")
        .with(query: hash_including("q" => "Ruby", "key" => "test_key", "cx" => "test_cse_id"))
        .to_return(status: 200, body: JSON.generate(body))

      result = tool.call(query: "Ruby")
      expect(result).to include("Ruby Lang")
    end

    it "handles empty results" do
      stub_request(:get, %r{www\.googleapis\.com/customsearch/v1})
        .to_return(status: 200, body: JSON.generate({ "items" => nil }))

      result = tool.call(query: "test")
      expect(result.to_s).to include("No results found")
    end

    it "requires API key" do
      expect { described_class.new(cse_id: "test") }.to raise_error(ArgumentError, /Missing API key/)
    end

    it "requires Search Engine ID" do
      expect { described_class.new(api_key: "test") }.to raise_error(ArgumentError, /Google Search Engine ID/)
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
                                                      ] }
                                                    }))

      result = tool.call(query: "AI")
      expect(result).to include("AI Guide")
    end

    it "handles empty results" do
      stub_request(:get, %r{api\.search\.brave\.com/res/v1/web/search})
        .to_return(status: 200, body: JSON.generate({ "web" => { "results" => [] } }))

      result = tool.call(query: "test")
      expect(result.to_s).to include("No results found")
    end

    it "has rate limiting configured" do
      expect(tool.instance_variable_get(:@rate_limit)).to eq(1.0)
      expect(tool.instance_variable_get(:@min_interval)).to eq(1.0)
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
      allow(ENV).to receive(:fetch).and_call_original
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
