module Smolagents
  module Tools
    module SpeechToText
      # Callback handling for transcription completion events.
      module Callbacks
        # Register callback for transcription completion events.
        # @yield [transcript_id, text] Called when transcription completes
        # @return [self] For chaining
        def on_transcription_complete(&block)
          @completion_callbacks << block
          self
        end

        private

        def initialize_callbacks
          @completion_callbacks = []
        end

        def notify_completion(transcript_id, text)
          @completion_callbacks&.each { |cb| cb.call(transcript_id, text) }
        end
      end
    end
  end
end
