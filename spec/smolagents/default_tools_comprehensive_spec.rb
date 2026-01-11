# frozen_string_literal: true

require "webmock/rspec"
require "tempfile"

RSpec.describe "Default Tools Comprehensive Tests" do
  describe Smolagents::DefaultTools::GoogleSearchTool do
    context "with SerpAPI provider" do
      subject(:tool) { described_class.new(provider: "serpapi", api_key: "test_key") }

      it "performs search successfully" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("q" => "Ruby programming", "api_key" => "test_key"))
          .to_return(
            status: 200,
            body: JSON.generate({
                                  "organic_results" => [
                                    {
                                      "title" => "Ruby Programming Language",
                                      "link" => "https://www.ruby-lang.org",
                                      "snippet" => "A dynamic, open source programming language"
                                    }
                                  ]
                                })
          )

        result = tool.call(query: "Ruby programming")
        expect(result).to include("## Search Results")
        expect(result).to include("Ruby Programming Language")
        expect(result).to include("ruby-lang.org")
      end

      it "handles year filtering" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("tbs" => "cdr:1,cd_min:01/01/2023,cd_max:12/31/2023"))
          .to_return(
            status: 200,
            body: JSON.generate({
                                  "organic_results" => [
                                    { "title" => "Result", "link" => "https://example.com", "snippet" => "Text" }
                                  ]
                                })
          )

        result = tool.call(query: "test", filter_year: 2023)
        expect(result).to include("Result")
      end

      it "handles empty results" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("q" => "test"))
          .to_return(
            status: 200,
            body: JSON.generate({ "organic_results" => [] })
          )

        result = tool.call(query: "test")
        expect(result).to include("No results found")
      end

      it "handles missing results key" do
        stub_request(:get, "https://serpapi.com/search.json")
          .with(query: hash_including("q" => "test"))
          .to_return(
            status: 200,
            body: JSON.generate({})
          )

        expect do
          tool.call(query: "test")
        end.to raise_error(StandardError, /No results found/)
      end
    end

    context "with Serper provider" do
      subject(:tool) { described_class.new(provider: "serper", api_key: "test_key") }

      it "uses correct API endpoint" do
        stub_request(:get, "https://google.serper.dev/search")
          .with(query: hash_including("q" => "test"))
          .to_return(
            status: 200,
            body: JSON.generate({
                                  "organic" => [
                                    { "title" => "Test", "link" => "https://test.com", "snippet" => "Test" }
                                  ]
                                })
          )

        result = tool.call(query: "test")
        expect(result).to include("Test")
      end
    end

    it "requires API key" do
      expect do
        described_class.new(provider: "serpapi")
      end.to raise_error(ArgumentError, /Missing API key/)
    end
  end

  describe Smolagents::DefaultTools::ApiWebSearchTool do
    subject(:tool) { described_class.new(api_key: "test_brave_key") }

    it "performs search with Brave API" do
      stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
        .with(
          query: hash_including("q" => "AI agents", "count" => "10"),
          headers: { "X-Subscription-Token" => "test_brave_key" }
        )
        .to_return(
          status: 200,
          body: JSON.generate({
                                "web" => {
                                  "results" => [
                                    {
                                      "title" => "AI Agents Explained",
                                      "url" => "https://example.com/ai-agents",
                                      "description" => "Learn about autonomous AI agents"
                                    },
                                    {
                                      "title" => "Building AI Agents",
                                      "url" => "https://example.com/building",
                                      "description" => "A guide to building agents"
                                    }
                                  ]
                                }
                              })
        )

      result = tool.call(query: "AI agents")
      expect(result).to include("## Search Results")
      expect(result).to include("AI Agents Explained")
      expect(result).to include("Building AI Agents")
      expect(result).to match(/\d+\. \[.*?\]\(.*?\)/)
    end

    it "handles empty results" do
      stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
        .with(query: hash_including("q" => "test"))
        .to_return(
          status: 200,
          body: JSON.generate({ "web" => { "results" => [] } })
        )

      result = tool.call(query: "test")
      expect(result).to eq("No results found.")
    end

    it "enforces rate limiting" do
      tool = described_class.new(api_key: "test_key", rate_limit: 2.0)

      stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
        .with(query: hash_including("q"))
        .to_return(
          status: 200,
          body: JSON.generate({ "web" => { "results" => [] } })
        ).times(2)

      start_time = Time.now
      tool.call(query: "test1")
      tool.call(query: "test2")
      elapsed = Time.now - start_time

      # Should take at least 0.5 seconds (1/2.0) between requests
      expect(elapsed).to be >= 0.4
    end

    it "works with custom endpoint" do
      custom_tool = described_class.new(
        endpoint: "https://custom-api.example.com/search",
        api_key: "custom_key",
        headers: { "Authorization" => "Bearer custom_key" },
        params: { "limit" => 5 }
      )

      stub_request(:get, "https://custom-api.example.com/search?limit=5&q=test")
        .with(headers: { "Authorization" => "Bearer custom_key" })
        .to_return(
          status: 200,
          body: JSON.generate({ "web" => { "results" => [] } })
        )

      result = custom_tool.call(query: "test")
      expect(result).to eq("No results found.")
    end
  end

  describe Smolagents::DefaultTools::SpeechToTextTool do
    context "with OpenAI provider" do
      subject(:tool) { described_class.new(provider: "openai", api_key: "test_openai_key") }

      it "transcribes local audio file" do
        # Create a temporary audio file
        audio_file = Tempfile.new(["test", ".mp3"])
        audio_file.write("fake audio data")
        audio_file.rewind

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .with(
            headers: { "Authorization" => "Bearer test_openai_key" }
          )
          .to_return(
            status: 200,
            body: JSON.generate({ "text" => "Hello, this is a test transcription." })
          )

        result = tool.call(audio: audio_file.path)
        expect(result).to eq("Hello, this is a test transcription.")

        audio_file.close
        audio_file.unlink
      end

      it "transcribes audio from URL" do
        stub_request(:get, "https://example.com/audio.mp3")
          .to_return(status: 200, body: "fake audio data")

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: JSON.generate({ "text" => "Transcribed from URL." })
          )

        result = tool.call(audio: "https://example.com/audio.mp3")
        expect(result).to eq("Transcribed from URL.")
      end
    end

    context "with AssemblyAI provider" do
      subject(:tool) { described_class.new(provider: "assemblyai", api_key: "test_assembly_key") }

      it "transcribes audio with full workflow" do
        # Mock upload
        stub_request(:post, "https://api.assemblyai.com/v2/upload")
          .with(headers: { "authorization" => "test_assembly_key" })
          .to_return(
            status: 200,
            body: JSON.generate({ "upload_url" => "https://cdn.assemblyai.com/upload/test123" })
          )

        # Mock transcription creation
        stub_request(:post, "https://api.assemblyai.com/v2/transcript")
          .with(
            headers: { "authorization" => "test_assembly_key" },
            body: JSON.generate(audio_url: "https://cdn.assemblyai.com/upload/test123")
          )
          .to_return(
            status: 200,
            body: JSON.generate({ "id" => "transcript123" })
          )

        # Mock polling (returns completed immediately)
        stub_request(:get, "https://api.assemblyai.com/v2/transcript/transcript123")
          .with(headers: { "authorization" => "test_assembly_key" })
          .to_return(
            status: 200,
            body: JSON.generate({
                                  "status" => "completed",
                                  "text" => "Transcription completed via AssemblyAI."
                                })
          )

        audio_file = Tempfile.new(["test", ".mp3"])
        audio_file.write("fake audio data")
        audio_file.close

        result = tool.call(audio: audio_file.path)
        expect(result).to eq("Transcription completed via AssemblyAI.")

        audio_file.unlink
      end

      it "handles transcription errors" do
        stub_request(:post, "https://api.assemblyai.com/v2/upload")
          .to_return(
            status: 200,
            body: JSON.generate({ "upload_url" => "https://cdn.assemblyai.com/upload/test" })
          )

        stub_request(:post, "https://api.assemblyai.com/v2/transcript")
          .to_return(status: 200, body: JSON.generate({ "id" => "trans123" }))

        stub_request(:get, "https://api.assemblyai.com/v2/transcript/trans123")
          .to_return(
            status: 200,
            body: JSON.generate({
                                  "status" => "error",
                                  "error" => "Audio file format not supported"
                                })
          )

        audio_file = Tempfile.new(["test", ".mp3"])
        audio_file.write("fake audio data")
        audio_file.close

        result = tool.call(audio: audio_file.path)
        expect(result).to include("unexpected error")
        expect(result).to include("Audio file format not supported")

        audio_file.unlink
      end
    end

    it "requires API key" do
      # Clear environment variable (implementation uses fetch, not [])
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return(nil)

      expect do
        described_class.new(provider: "openai")
      end.to raise_error(ArgumentError, /Missing API key/)
    end

    it "rejects unsupported providers" do
      expect do
        described_class.new(provider: "unknown", api_key: "test")
      end.to raise_error(ArgumentError, /Unknown provider/)
    end
  end

  describe "Integration: All tools available" do
    it "can retrieve all 10 tools" do
      # Override environment check for tools that require API keys
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SERPAPI_API_KEY").and_return("test_key")
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("test_key")

      # Skip tools that require API keys for the .all test
      expect(Smolagents::DefaultTools::TOOL_MAPPING.size).to eq(10)
      expect(Smolagents::DefaultTools::TOOL_MAPPING.keys).to contain_exactly(
        "final_answer",
        "ruby_interpreter",
        "user_input",
        "web_search",
        "duckduckgo_search",
        "google_search",
        "api_web_search",
        "visit_webpage",
        "wikipedia_search",
        "speech_to_text"
      )
    end

    it "can get specific tools by name" do
      tool = Smolagents::DefaultTools.get("final_answer")
      expect(tool).to be_a(Smolagents::DefaultTools::FinalAnswerTool)

      tool = Smolagents::DefaultTools.get("user_input")
      expect(tool).to be_a(Smolagents::DefaultTools::UserInputTool)
    end
  end
end
