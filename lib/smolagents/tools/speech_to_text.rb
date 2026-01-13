require "faraday"
require "faraday/multipart"
require "json"

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
    # @example Basic usage with OpenAI Whisper (synchronous)
    #   tool = SpeechToTextTool.new(provider: "openai")
    #   result = tool.call(audio: "/path/to/recording.mp3")
    #   puts result.data  # => "Transcribed text..."
    #
    # @example Using AssemblyAI provider (asynchronous)
    #   tool = SpeechToTextTool.new(provider: "assemblyai")
    #
    #   # Start transcription - returns immediately with job
    #   result = tool.call(audio: "/path/to/interview.m4a")
    #   job = result.data
    #
    #   # Check status later (non-blocking)
    #   status = tool.check_status(job.transcript_id)
    #   case status
    #   in { status: "completed", text: }
    #     puts text
    #   in { status: "processing" }
    #     # Still processing - check again later via callback/scheduler
    #   in { status: "error", error: }
    #     raise error
    #   end
    #
    # @example Event-driven completion handling
    #   tool.on_transcription_complete do |transcript_id, text|
    #     process_transcript(text)
    #   end
    #
    # @see Tool Base class for all tools
    # @see Concerns::ApiKey For API key resolution
    class SpeechToTextTool < Tool
      include Concerns::ApiKey

      self.tool_name = "transcribe"
      self.description = "Convert audio to text. Supports common audio formats (mp3, wav, m4a)."
      self.inputs = { audio: { type: "string", description: "Path or URL to the audio file" } }
      self.output_type = "string"

      # Represents an async transcription job (AssemblyAI)
      TranscriptionJob = Data.define(:transcript_id, :status, :audio_url, :created_at) do
        def pending? = %w[processing queued].include?(status)
        def completed? = status == "completed"
        def failed? = status == "error"
      end

      # Supported providers with their API configurations.
      # @api private
      PROVIDERS = {
        "openai" => { env: "OPENAI_API_KEY", endpoint: "https://api.openai.com/v1/audio/transcriptions" },
        "assemblyai" => { env: "ASSEMBLYAI_API_KEY", endpoint: "https://api.assemblyai.com/v2/upload" }
      }.freeze

      # Creates a new speech-to-text tool.
      #
      # @param provider [String] Transcription provider ("openai" or "assemblyai")
      # @param api_key [String, nil] API key for the provider. If nil, reads from
      #   environment variable (OPENAI_API_KEY or ASSEMBLYAI_API_KEY)
      # @param model [String] Model to use for transcription (OpenAI only, default: "whisper-1")
      #
      # @raise [ArgumentError] If provider is unknown or API key is missing
      #
      # @example
      #   SpeechToTextTool.new(provider: "openai", model: "whisper-1")
      #   SpeechToTextTool.new(provider: "assemblyai", api_key: "your-key")
      def initialize(provider: "openai", api_key: nil, model: "whisper-1")
        super()
        @provider = provider
        @model = model
        config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
        @endpoint = config[:endpoint]
        @completion_callbacks = []
      end

      # Register callback for transcription completion events.
      # @yield [transcript_id, text] Called when transcription completes
      # @return [self] For chaining
      def on_transcription_complete(&block)
        @completion_callbacks << block
        self
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
      #
      # @example OpenAI (synchronous)
      #   tool.execute(audio: "/home/user/recording.mp3")
      #   # => "Hello, this is a test recording..."
      #
      # @example AssemblyAI (async)
      #   job = tool.execute(audio: "/path/to/audio.mp3")
      #   # => TranscriptionJob[transcript_id: "abc123", status: "processing", ...]
      #   # Later: tool.check_status(job.transcript_id)
      def execute(audio:)
        @provider == "openai" ? transcribe_openai(audio) : transcribe_assemblyai(audio)
      rescue Faraday::Error => e
        "Error: #{e.message}"
      end

      # Check status of an AssemblyAI transcription job.
      # Non-blocking - returns current status immediately.
      #
      # @param transcript_id [String] The transcript ID from TranscriptionJob
      # @return [Hash] Status hash with :status key and :text (if completed) or :error (if failed)
      #
      # @example
      #   status = tool.check_status("abc123")
      #   case status
      #   in { status: "completed", text: }
      #     process(text)
      #   in { status: "processing" }
      #     # Schedule another check
      #   in { status: "error", error: }
      #     handle_error(error)
      #   end
      def check_status(transcript_id)
        conn = Faraday.new
        response = conn.get("https://api.assemblyai.com/v2/transcript/#{transcript_id}") do |req|
          req.headers["authorization"] = @api_key
        end
        result = JSON.parse(response.body)

        case result["status"]
        when "completed"
          text = result["text"]
          notify_completion(transcript_id, text)
          { status: "completed", text: }
        when "error"
          { status: "error", error: result["error"] }
        else
          { status: result["status"] }
        end
      end

      private

      # Transcribes audio using OpenAI Whisper API.
      # @api private
      def transcribe_openai(audio)
        conn = Faraday.new(url: @endpoint) { |faraday| faraday.request :multipart }
        audio_data = audio.start_with?("http") ? Faraday.new.get(audio).body : File.read(audio)

        response = conn.post do |req|
          req.headers["Authorization"] = "Bearer #{@api_key}"
          req.body = {
            file: Faraday::Multipart::FilePart.new(StringIO.new(audio_data), "audio/mpeg", File.basename(audio)),
            model: @model
          }
        end
        JSON.parse(response.body)["text"]
      end

      # Starts async transcription using AssemblyAI API.
      # Returns immediately with a TranscriptionJob - use check_status to poll.
      # @api private
      def transcribe_assemblyai(audio)
        conn = Faraday.new
        audio_url = audio.start_with?("http") ? audio : upload_to_assemblyai(conn, audio)

        response = conn.post("https://api.assemblyai.com/v2/transcript") do |req|
          req.headers["authorization"] = @api_key
          req.headers["content-type"] = "application/json"
          req.body = JSON.generate(audio_url: audio_url)
        end

        result = JSON.parse(response.body)
        TranscriptionJob.new(
          transcript_id: result["id"],
          status: result["status"],
          audio_url: audio_url,
          created_at: Time.now
        )
      end

      # Uploads a local file to AssemblyAI's upload endpoint.
      # @api private
      def upload_to_assemblyai(conn, file_path)
        response = conn.post("https://api.assemblyai.com/v2/upload") do |req|
          req.headers["authorization"] = @api_key
          req.body = File.read(file_path)
        end
        JSON.parse(response.body)["upload_url"]
      end

      def notify_completion(transcript_id, text)
        @completion_callbacks&.each { |cb| cb.call(transcript_id, text) }
      end
    end
  end

  # Re-export SpeechToTextTool at the Smolagents level
  # @see Smolagents::Tools::SpeechToTextTool
  SpeechToTextTool = Tools::SpeechToTextTool
end
