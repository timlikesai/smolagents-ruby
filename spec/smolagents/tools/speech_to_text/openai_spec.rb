require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::OpenAI do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::SpeechToText::OpenAI

      attr_accessor :api_key, :endpoint, :model

      # Expose private methods for testing
      public :transcribe_openai, :build_multipart_connection, :fetch_audio_data, :build_file_part
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.api_key = "test-api-key"
    obj.endpoint = "https://api.openai.com/v1/audio/transcriptions"
    obj.model = "whisper-1"
    obj
  end

  describe "#transcribe_openai" do
    it "returns transcribed text from OpenAI" do
      allow(File).to receive(:read).with("/path/to/audio.mp3").and_return("fake-audio-data")

      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .to_return(
          status: 200,
          body: { text: "Hello, this is transcribed text" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = instance.transcribe_openai("/path/to/audio.mp3")

      expect(result).to eq("Hello, this is transcribed text")
    end

    it "fetches remote audio for URL inputs" do
      stub_request(:get, "https://example.com/audio.mp3")
        .to_return(status: 200, body: "audio-data")

      stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
        .to_return(
          status: 200,
          body: { text: "Transcribed from URL" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = instance.transcribe_openai("https://example.com/audio.mp3")

      expect(result).to eq("Transcribed from URL")
    end
  end

  describe "#build_multipart_connection" do
    it "creates a Faraday connection with multipart support" do
      conn = instance.build_multipart_connection

      expect(conn).to be_a(Faraday::Connection)
      expect(conn.url_prefix.to_s).to eq("https://api.openai.com/v1/audio/transcriptions")
    end
  end

  describe "#fetch_audio_data" do
    it "reads local files directly" do
      # Create a temporary file for testing
      file_content = "fake-audio-data"
      allow(File).to receive(:read).with("/path/to/audio.mp3").and_return(file_content)

      result = instance.fetch_audio_data("/path/to/audio.mp3")

      expect(result).to eq(file_content)
    end

    it "fetches remote URLs via HTTP" do
      stub_request(:get, "https://example.com/audio.mp3")
        .to_return(status: 200, body: "remote-audio-data")

      result = instance.fetch_audio_data("https://example.com/audio.mp3")

      expect(result).to eq("remote-audio-data")
    end
  end

  describe "#build_file_part" do
    it "creates a Faraday FilePart" do
      audio_data = "fake-audio-bytes"
      part = instance.build_file_part("/path/to/test.mp3", audio_data)

      expect(part).to be_a(Faraday::Multipart::FilePart)
      expect(part.original_filename).to eq("test.mp3")
      expect(part.content_type).to eq("audio/mpeg")
    end

    it "extracts filename from URL paths" do
      audio_data = "fake-audio-bytes"
      part = instance.build_file_part("https://example.com/files/podcast.mp3", audio_data)

      expect(part.original_filename).to eq("podcast.mp3")
    end
  end
end
