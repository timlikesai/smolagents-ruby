module Smolagents
  module Tools
    module SpeechToText
      # Provider configurations for speech-to-text APIs.
      module Providers
        # Supported audio formats across providers.
        AUDIO_FORMATS = %w[mp3 wav m4a ogg flac webm].freeze

        # Provider-specific API configurations.
        CONFIGS = {
          "openai" => {
            env: "OPENAI_API_KEY",
            endpoint: "https://api.openai.com/v1/audio/transcriptions"
          }.freeze,
          "assemblyai" => {
            env: "ASSEMBLYAI_API_KEY",
            endpoint: "https://api.assemblyai.com/v2/upload"
          }.freeze
        }.freeze

        # AssemblyAI API endpoints.
        ASSEMBLYAI_TRANSCRIPT_URL = "https://api.assemblyai.com/v2/transcript".freeze
        ASSEMBLYAI_UPLOAD_URL = "https://api.assemblyai.com/v2/upload".freeze
      end
    end
  end
end
