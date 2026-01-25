require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::Status do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::SpeechToText::Callbacks
      include Smolagents::Tools::SpeechToText::Status

      attr_accessor :api_key

      def initialize
        initialize_callbacks
      end

      # Expose private methods for testing
      public :fetch_transcript_status, :build_status_response, :completed_status
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.api_key = "test-api-key"
    obj
  end

  describe "#check_status" do
    it "returns completed status with text" do
      stub_request(:get, "#{Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL}/transcript123")
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { status: "completed", text: "Hello world" }.to_json
        )

      result = instance.check_status("transcript123")

      expect(result[:status]).to eq("completed")
      expect(result[:text]).to eq("Hello world")
    end

    it "returns processing status" do
      stub_request(:get, "#{Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL}/transcript456")
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { status: "processing" }.to_json
        )

      result = instance.check_status("transcript456")

      expect(result[:status]).to eq("processing")
      expect(result).not_to have_key(:text)
    end

    it "returns error status with error message" do
      stub_request(:get, "#{Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL}/transcript789")
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { status: "error", error: "Invalid audio format" }.to_json
        )

      result = instance.check_status("transcript789")

      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq("Invalid audio format")
    end

    it "notifies callbacks on completion" do
      stub_request(:get, "#{Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL}/transcript123")
        .to_return(
          status: 200,
          body: { status: "completed", text: "Transcribed text" }.to_json
        )

      callback_called = false
      received_id = nil
      received_text = nil

      instance.on_transcription_complete do |id, text|
        callback_called = true
        received_id = id
        received_text = text
      end

      instance.check_status("transcript123")

      expect(callback_called).to be true
      expect(received_id).to eq("transcript123")
      expect(received_text).to eq("Transcribed text")
    end
  end

  describe "#fetch_transcript_status (private)" do
    it "fetches status from AssemblyAI API" do
      stub_request(:get, "#{Smolagents::Tools::SpeechToText::Providers::ASSEMBLYAI_TRANSCRIPT_URL}/abc")
        .with(headers: { "authorization" => "test-api-key" })
        .to_return(
          status: 200,
          body: { status: "queued", id: "abc" }.to_json
        )

      result = instance.fetch_transcript_status("abc")

      expect(result["status"]).to eq("queued")
      expect(result["id"]).to eq("abc")
    end
  end

  describe "#build_status_response (private)" do
    it "handles completed status" do
      result = { "status" => "completed", "text" => "Hello" }

      response = instance.build_status_response(result, "id123")

      expect(response[:status]).to eq("completed")
      expect(response[:text]).to eq("Hello")
    end

    it "handles error status" do
      result = { "status" => "error", "error" => "Something went wrong" }

      response = instance.build_status_response(result, "id123")

      expect(response[:status]).to eq("error")
      expect(response[:error]).to eq("Something went wrong")
    end

    it "handles other statuses" do
      result = { "status" => "queued" }

      response = instance.build_status_response(result, "id123")

      expect(response).to eq({ status: "queued" })
    end
  end

  describe "#completed_status (private)" do
    it "returns status hash with text" do
      result = { "status" => "completed", "text" => "Transcribed content" }

      response = instance.completed_status(result, "id123")

      expect(response[:status]).to eq("completed")
      expect(response[:text]).to eq("Transcribed content")
    end

    it "triggers completion callbacks" do
      result = { "status" => "completed", "text" => "Test" }
      callback_triggered = false

      instance.on_transcription_complete { callback_triggered = true }
      instance.completed_status(result, "id123")

      expect(callback_triggered).to be true
    end
  end
end
