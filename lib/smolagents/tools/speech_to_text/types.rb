module Smolagents
  module Tools
    module SpeechToText
      # Types for speech-to-text transcription results.
      module Types
        # Represents an async transcription job (AssemblyAI).
        #
        # Use {#pending?}, {#completed?}, or {#failed?} to check status.
        # Poll with {SpeechToTextTool#check_status} to get updates.
        TranscriptionJob = Data.define(:transcript_id, :status, :audio_url, :created_at) do
          def pending? = %w[processing queued].include?(status)
          def completed? = status == "completed"
          def failed? = status == "error"
        end
      end
    end
  end
end
