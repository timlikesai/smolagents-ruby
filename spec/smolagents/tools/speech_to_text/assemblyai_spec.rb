require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::AssemblyAI do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::SpeechToText::AssemblyAI

      attr_accessor :api_key

      # Expose private methods for testing
      public :transcribe_assemblyai, :resolve_audio_url, :post_assemblyai_transcription,
             :build_transcription_job, :upload_to_assemblyai
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.api_key = "test-api-key"
    obj
  end

  describe "#transcribe_assemblyai" do
    it "returns a TranscriptionJob for remote URLs" do
      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL)
        .with(
          headers: { "authorization" => "test-api-key" },
          body: { audio_url: "https://example.com/audio.mp3" }.to_json
        )
        .to_return(
          status: 200,
          body: { id: "transcript123", status: "queued" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      Timecop.freeze(Time.now) do
        result = instance.transcribe_assemblyai("https://example.com/audio.mp3")

        expect(result).to be_a(Smolagents::Tools::SpeechToText::Types::TranscriptionJob)
        expect(result.transcript_id).to eq("transcript123")
        expect(result.status).to eq("queued")
        expect(result.audio_url).to eq("https://example.com/audio.mp3")
        expect(result.created_at).to eq(Time.now)
      end
    end

    it "uploads local files before transcribing" do
      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_UPLOAD_URL)
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { upload_url: "https://assemblyai.com/uploaded/abc.mp3" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL)
        .to_return(
          status: 200,
          body: { id: "transcript456", status: "processing" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      allow(File).to receive(:read).with("/path/to/audio.mp3").and_return("audio-bytes")

      result = instance.transcribe_assemblyai("/path/to/audio.mp3")

      expect(result.audio_url).to eq("https://assemblyai.com/uploaded/abc.mp3")
    end
  end

  describe "#resolve_audio_url" do
    let(:conn) { Faraday.new }

    it "returns URL as-is for http URLs" do
      result = instance.resolve_audio_url(conn, "https://example.com/audio.mp3")

      expect(result).to eq("https://example.com/audio.mp3")
    end

    it "uploads local files and returns upload URL" do
      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_UPLOAD_URL)
        .to_return(
          status: 200,
          body: { upload_url: "https://assemblyai.com/uploaded/file.mp3" }.to_json
        )

      allow(File).to receive(:read).with("/local/file.mp3").and_return("audio-data")

      result = instance.resolve_audio_url(conn, "/local/file.mp3")

      expect(result).to eq("https://assemblyai.com/uploaded/file.mp3")
    end
  end

  describe "#post_assemblyai_transcription" do
    let(:conn) { Faraday.new }

    it "posts to transcript endpoint with audio URL" do
      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL)
        .with(
          headers: { "authorization" => "test-api-key", "content-type" => "application/json" },
          body: { audio_url: "https://example.com/audio.mp3" }.to_json
        )
        .to_return(
          status: 200,
          body: { id: "t123", status: "queued" }.to_json
        )

      result = instance.post_assemblyai_transcription(conn, "https://example.com/audio.mp3")

      expect(result["id"]).to eq("t123")
      expect(result["status"]).to eq("queued")
    end
  end

  describe "#build_transcription_job" do
    it "creates a TranscriptionJob from API response" do
      result = { "id" => "job123", "status" => "processing" }

      Timecop.freeze(Time.now) do
        job = instance.build_transcription_job(result, "https://example.com/audio.mp3")

        expect(job.transcript_id).to eq("job123")
        expect(job.status).to eq("processing")
        expect(job.audio_url).to eq("https://example.com/audio.mp3")
        expect(job.created_at).to eq(Time.now)
      end
    end
  end

  describe "#upload_to_assemblyai" do
    let(:conn) { Faraday.new }

    it "uploads file and returns upload URL" do
      stub_request(:post, Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_UPLOAD_URL)
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { upload_url: "https://assemblyai.com/stored/xyz.mp3" }.to_json
        )

      allow(File).to receive(:read).with("/path/to/file.mp3").and_return("binary-data")

      result = instance.upload_to_assemblyai(conn, "/path/to/file.mp3")

      expect(result).to eq("https://assemblyai.com/stored/xyz.mp3")
    end
  end
end
