require "webmock/rspec"

RSpec.describe Smolagents::SpeechToTextTool do
  let(:valid_args) { { audio: "test.mp3" } }
  let(:required_input_name) { :audio }

  describe "tool metadata" do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("transcribe")
    end

    it "has description" do
      expect(described_class.description).to include("audio")
    end

    it "has audio input" do
      expect(described_class.inputs).to have_key(:audio)
    end

    it "outputs string" do
      expect(described_class.output_type).to eq("string")
    end
  end

  describe "initialization" do
    context "with OpenAI provider" do
      it "initializes with default model" do
        api_key = ENV["OPENAI_API_KEY"] || "test_key"
        tool = described_class.new(provider: "openai", api_key:)

        expect(tool.instance_variable_get(:@provider)).to eq("openai")
      end

      it "accepts custom model" do
        api_key = ENV["OPENAI_API_KEY"] || "test_key"
        tool = described_class.new(provider: "openai", api_key:, model: "whisper-2")

        expect(tool.instance_variable_get(:@model)).to eq("whisper-2")
      end
    end

    context "with AssemblyAI provider" do
      it "initializes with AssemblyAI" do
        api_key = ENV["ASSEMBLYAI_API_KEY"] || "test_key"
        tool = described_class.new(provider: "assemblyai", api_key:)

        expect(tool.instance_variable_get(:@provider)).to eq("assemblyai")
      end
    end

    context "with unknown provider" do
      it "raises error for invalid provider" do
        expect do
          described_class.new(provider: "unknown", api_key: "key")
        end.to raise_error(ArgumentError)
      end
    end

    context "without API key" do
      it "reads from environment variable for OpenAI" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return("env_key")

        tool = described_class.new(provider: "openai")

        expect(tool.instance_variable_get(:@api_key)).to eq("env_key")
      end

      it "reads from environment variable for AssemblyAI" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ASSEMBLYAI_API_KEY", nil).and_return("env_key")

        tool = described_class.new(provider: "assemblyai")

        expect(tool.instance_variable_get(:@api_key)).to eq("env_key")
      end

      it "raises error when API key missing" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return(nil)

        expect do
          described_class.new(provider: "openai")
        end.to raise_error(ArgumentError, /Missing API key/)
      end
    end
  end

  describe "#call" do
    context "with OpenAI provider" do
      let(:tool) do
        described_class.new(
          provider: "openai",
          api_key: "test_key"
        )
      end

      before do
        allow(File).to receive(:read).with("test.mp3").and_return("fake audio data")
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .with(headers: { "Authorization" => "Bearer test_key" })
          .to_return(status: 200, body: { text: "Hello world" }.to_json)
      end

      it "transcribes audio to text" do
        result = tool.call(audio: "test.mp3")

        expect(result).to be_a(Smolagents::ToolResult)
      end

      it "returns transcribed text" do
        result = tool.call(audio: "test.mp3")

        expect(result.data).to include("Hello world")
      end

      it "wraps result in ToolResult" do
        result = tool.call(audio: "test.mp3")

        expect(result.tool_name).to eq("transcribe")
      end
    end

    context "with invalid audio file" do
      let(:tool) do
        described_class.new(
          provider: "openai",
          api_key: "test_key"
        )
      end

      before do
        allow(File).to receive(:read).with("invalid.mp3").and_return("fake audio data")
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 400, body: { error: "Invalid audio" }.to_json)
      end

      it "handles HTTP errors" do
        result = tool.call(audio: "invalid.mp3")

        # Should return error wrapped in ToolResult
        expect(result).to be_a(Smolagents::ToolResult)
      end
    end
  end

  describe "#execute" do
    context "with OpenAI provider" do
      let(:tool) do
        described_class.new(
          provider: "openai",
          api_key: "test_key"
        )
      end

      before do
        allow(File).to receive(:read).with("audio.mp3").and_return("fake audio data")
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(status: 200, body: { text: "Transcribed text" }.to_json)
      end

      it "executes transcription" do
        result = tool.execute(audio: "audio.mp3")

        expect(result).to be_a(String)
      end
    end
  end

  describe "provider configuration" do
    it "recognizes openai provider" do
      tool = described_class.new(
        provider: "openai",
        api_key: "test_key"
      )

      expect(tool.instance_variable_get(:@provider)).to eq("openai")
    end

    it "recognizes assemblyai provider" do
      tool = described_class.new(
        provider: "assemblyai",
        api_key: "test_key"
      )

      expect(tool.instance_variable_get(:@provider)).to eq("assemblyai")
    end

    it "stores endpoint for provider" do
      tool = described_class.new(
        provider: "openai",
        api_key: "test_key"
      )

      endpoint = tool.instance_variable_get(:@endpoint)
      expect(endpoint).not_to be_nil
    end
  end

  describe "tool validation" do
    it "has name" do
      tool = described_class.new(
        provider: "openai",
        api_key: "test_key"
      )

      expect(tool.name).to eq("transcribe")
    end

    it "has description" do
      tool = described_class.new(
        provider: "openai",
        api_key: "test_key"
      )

      expect(tool.description).not_to be_empty
    end

    it "has inputs schema" do
      tool = described_class.new(
        provider: "openai",
        api_key: "test_key"
      )

      expect(tool.inputs).to have_key(:audio)
      expect(tool.inputs[:audio][:type]).to eq("string")
    end
  end

  describe "audio file handling" do
    let(:tool) do
      described_class.new(
        provider: "openai",
        api_key: "test_key"
      )
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .to_return(status: 200, body: { text: "Result" }.to_json)
      stub_request(:get, %r{https://example\.com/.*})
        .to_return(status: 200, body: "fake audio data")
      allow(File).to receive(:read).and_return("fake audio data")
    end

    it "accepts local file paths" do
      result = tool.call(audio: "/local/path/audio.mp3")

      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "accepts remote URLs" do
      result = tool.call(audio: "https://example.com/audio.mp3")

      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "accepts various audio formats" do
      formats = %w[mp3 wav m4a flac ogg]

      formats.each do |fmt|
        result = tool.call(audio: "audio.#{fmt}")
        expect(result).to be_a(Smolagents::ToolResult)
      end
    end
  end

  describe "error handling" do
    let(:tool) do
      described_class.new(
        provider: "openai",
        api_key: "test_key"
      )
    end

    before do
      allow(File).to receive(:read).with("audio.mp3").and_return("fake audio data")
    end

    it "handles authentication errors with JSON response" do
      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .to_return(status: 401, body: { error: "Unauthorized" }.to_json)

      result = tool.call(audio: "audio.mp3")

      # Should return error wrapped in ToolResult
      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "handles network errors gracefully" do
      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .to_raise(Faraday::ConnectionFailed.new("Network error"))

      result = tool.call(audio: "audio.mp3")

      expect(result).to be_a(Smolagents::ToolResult)
    end
  end

  describe "tool formatting" do
    let(:tool) do
      described_class.new(
        provider: "openai",
        api_key: "test_key"
      )
    end

    it "formats for code" do
      format = tool.format_for(:code)

      expect(format).to be_a(String)
      expect(format).to include("transcribe")
    end

    it "formats for default" do
      format = tool.format_for(:default)

      expect(format).to be_a(String)
      expect(format).to include(tool.name)
    end
  end
end
