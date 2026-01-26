require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::Providers do
  describe "AUDIO_FORMATS" do
    it "includes common audio formats" do
      formats = described_class::AUDIO_FORMATS

      expect(formats).to include("mp3")
      expect(formats).to include("wav")
      expect(formats).to include("m4a")
      expect(formats).to include("ogg")
      expect(formats).to include("flac")
      expect(formats).to include("webm")
    end

    it "is frozen" do
      expect(described_class::AUDIO_FORMATS).to be_frozen
    end
  end

  describe "CONFIGS" do
    it "includes openai configuration" do
      config = described_class::CONFIGS["openai"]

      expect(config[:env]).to eq("OPENAI_API_KEY")
      expect(config[:endpoint]).to eq("https://api.openai.com/v1/audio/transcriptions")
    end

    it "includes assemblyai configuration" do
      config = described_class::CONFIGS["assemblyai"]

      expect(config[:env]).to eq("ASSEMBLYAI_API_KEY")
      expect(config[:endpoint]).to eq("https://api.assemblyai.com/v2/upload")
    end

    it "is frozen" do
      expect(described_class::CONFIGS).to be_frozen
      expect(described_class::CONFIGS["openai"]).to be_frozen
      expect(described_class::CONFIGS["assemblyai"]).to be_frozen
    end
  end

  describe "ASSEMBLYAI_TRANSCRIPT_URL" do
    it "points to AssemblyAI transcript endpoint" do
      expect(described_class::ASSEMBLYAI_TRANSCRIPT_URL).to eq("https://api.assemblyai.com/v2/transcript")
    end

    it "is frozen" do
      expect(described_class::ASSEMBLYAI_TRANSCRIPT_URL).to be_frozen
    end
  end

  describe "ASSEMBLYAI_UPLOAD_URL" do
    it "points to AssemblyAI upload endpoint" do
      expect(described_class::ASSEMBLYAI_UPLOAD_URL).to eq("https://api.assemblyai.com/v2/upload")
    end

    it "is frozen" do
      expect(described_class::ASSEMBLYAI_UPLOAD_URL).to be_frozen
    end
  end
end
