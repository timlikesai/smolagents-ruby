require "faraday"
require "faraday/multipart"
require "json"

require_relative "support"
require_relative "speech_to_text/types"
require_relative "speech_to_text/providers"
require_relative "speech_to_text/callbacks"
require_relative "speech_to_text/openai"
require_relative "speech_to_text/assemblyai"
require_relative "speech_to_text/status"

module Smolagents
  module Tools
    # Converts audio files to text using speech-to-text APIs.
    #
    # SpeechToTextTool supports multiple transcription providers (OpenAI Whisper
    # and AssemblyAI) and handles both local files and remote URLs. Audio is
    # uploaded to the provider's API and transcribed to text.
    #
    # For OpenAI, transcription is synchronous and returns text directly.
    # For AssemblyAI, transcription is async - returns a TranscriptionJob that
    # can be checked for completion (no polling/sleeping).
    #
    # @see Tool Base class for all tools
    # @see Concerns::ApiKey For API key resolution
    class SpeechToTextTool < Tool
      include Concerns::ApiKey
      include Support::ErrorHandling
      include SpeechToText::Callbacks
      include SpeechToText::OpenAI
      include SpeechToText::AssemblyAI
      include SpeechToText::Status

      # Re-export TranscriptionJob at class level for backwards compatibility
      TranscriptionJob = SpeechToText::Types::TranscriptionJob

      self.tool_name = "transcribe"
      self.description = "Convert audio to text. Supports common audio formats (mp3, wav, m4a)."
      self.inputs = { audio: { type: "string", description: "Path or URL to the audio file" } }
      self.output_type = "string"

      # Creates a new speech-to-text tool.
      #
      # @param provider [String] Transcription provider ("openai" or "assemblyai")
      # @param api_key [String, nil] API key for the provider. If nil, reads from
      #   environment variable (OPENAI_API_KEY or ASSEMBLYAI_API_KEY)
      # @param model [String] Model to use for transcription (OpenAI only, default: "whisper-1")
      #
      # @raise [ArgumentError] If provider is unknown or API key is missing
      def initialize(provider: "openai", api_key: nil, model: "whisper-1")
        super()
        @provider = provider
        @model = model
        config, @api_key = configure_provider(provider, SpeechToText::Providers::CONFIGS, api_key:)
        @endpoint = config[:endpoint]
        initialize_callbacks
      end

      # Transcribes audio to text.
      #
      # For OpenAI: Returns transcribed text directly (synchronous).
      # For AssemblyAI: Returns TranscriptionJob (async, check with check_status).
      #
      # @param audio [String] Path to a local audio file or URL to remote audio
      # @return [String, TranscriptionJob] Text (OpenAI) or job (AssemblyAI)
      #
      # @raise [Faraday::Error] On HTTP errors (wrapped as error string)
      def execute(audio:)
        with_error_handling do
          @provider == "openai" ? transcribe_openai(audio) : transcribe_assemblyai(audio)
        end
      end
    end
  end

  # Re-export SpeechToTextTool at the Smolagents level
  # @see Smolagents::Tools::SpeechToTextTool
  SpeechToTextTool = Tools::SpeechToTextTool
end
