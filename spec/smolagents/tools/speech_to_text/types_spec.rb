require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::Types do
  describe Smolagents::Tools::SpeechToText::Types::TranscriptionJob do
    let(:job) do
      described_class.new(
        transcript_id: "abc123",
        status: "processing",
        audio_url: "https://example.com/audio.mp3",
        created_at: Time.now
      )
    end

    describe "#pending?" do
      it "returns true for processing status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "processing",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.pending?).to be true
      end

      it "returns true for queued status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "queued",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.pending?).to be true
      end

      it "returns false for completed status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "completed",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.pending?).to be false
      end
    end

    describe "#completed?" do
      it "returns true for completed status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "completed",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.completed?).to be true
      end

      it "returns false for processing status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "processing",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.completed?).to be false
      end
    end

    describe "#failed?" do
      it "returns true for error status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "error",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.failed?).to be true
      end

      it "returns false for processing status" do
        job = described_class.new(
          transcript_id: "abc123",
          status: "processing",
          audio_url: "https://example.com/audio.mp3",
          created_at: Time.now
        )

        expect(job.failed?).to be false
      end
    end

    describe "Data.define attributes" do
      it "provides access to transcript_id" do
        expect(job.transcript_id).to eq("abc123")
      end

      it "provides access to status" do
        expect(job.status).to eq("processing")
      end

      it "provides access to audio_url" do
        expect(job.audio_url).to eq("https://example.com/audio.mp3")
      end

      it "provides access to created_at" do
        expect(job.created_at).to be_a(Time)
      end
    end
  end
end
