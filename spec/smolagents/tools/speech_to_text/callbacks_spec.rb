require "spec_helper"

RSpec.describe Smolagents::Tools::SpeechToText::Callbacks do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::SpeechToText::Callbacks

      # Expose private methods for testing
      public :initialize_callbacks, :notify_completion
    end
  end

  let(:instance) { test_class.new }

  before { instance.initialize_callbacks }

  describe "#on_transcription_complete" do
    it "registers a callback" do
      called = false
      instance.on_transcription_complete { called = true }

      instance.notify_completion("id123", "Hello world")

      expect(called).to be true
    end

    it "returns self for chaining" do
      result = instance.on_transcription_complete { |_id, _text| nil }

      expect(result).to eq(instance)
    end

    it "supports multiple callbacks" do
      call_count = 0
      instance.on_transcription_complete { call_count += 1 }
      instance.on_transcription_complete { call_count += 1 }

      instance.notify_completion("id123", "Hello world")

      expect(call_count).to eq(2)
    end
  end

  describe "#notify_completion (private)" do
    it "passes transcript_id and text to callbacks" do
      received_id = nil
      received_text = nil

      instance.on_transcription_complete do |id, text|
        received_id = id
        received_text = text
      end

      instance.notify_completion("abc123", "Transcribed text")

      expect(received_id).to eq("abc123")
      expect(received_text).to eq("Transcribed text")
    end

    it "handles nil callbacks gracefully" do
      # Reset to nil to test nil safety
      instance.instance_variable_set(:@completion_callbacks, nil)

      expect { instance.notify_completion("id", "text") }.not_to raise_error
    end
  end

  describe "#initialize_callbacks (private)" do
    it "creates empty callbacks array" do
      fresh_instance = test_class.new
      fresh_instance.initialize_callbacks

      expect(fresh_instance.instance_variable_get(:@completion_callbacks)).to eq([])
    end
  end
end
