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
    # For OpenAI, transcription is synchronous. For AssemblyAI, the tool uploads
    # the audio, initiates transcription, and polls for completion.
    #
    # @example Basic usage with OpenAI Whisper
    #   tool = SpeechToTextTool.new(provider: "openai")
    #   # Requires OPENAI_API_KEY environment variable
    #
    #   # Transcribe a local file
    #   text = tool.call(audio: "/path/to/recording.mp3")
    #
    #   # Transcribe from URL
    #   text = tool.call(audio: "https://example.com/audio.wav")
    #
    # @example Using AssemblyAI provider
    #   tool = SpeechToTextTool.new(
    #     provider: "assemblyai",
    #     api_key: ENV["ASSEMBLYAI_API_KEY"]
    #   )
    #
    #   # AssemblyAI supports more formats and features
    #   text = tool.call(audio: "/path/to/interview.m4a")
    #
    # @example With a CodeAgent for voice-driven tasks
    #   speech_tool = SpeechToTextTool.new(provider: "openai")
    #   agent = CodeAgent.new(
    #     model: model,
    #     tools: [speech_tool, SearchTool.new]
    #   )
    #
    #   # Agent can process voice commands
    #   agent.run("Transcribe the audio at /tmp/voice_memo.mp3 and search for related topics")
    #
    # @see Tool Base class for all tools
    # @see Concerns::ApiKey For API key resolution
    class SpeechToTextTool < Tool
      include Concerns::ApiKey

      self.tool_name = "transcribe"
      self.description = "Convert audio to text. Supports common audio formats (mp3, wav, m4a)."
      self.inputs = { audio: { type: "string", description: "Path or URL to the audio file" } }
      self.output_type = "string"

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
      end

      # Transcribes audio to text.
      #
      # @param audio [String] Path to a local audio file or URL to remote audio
      # @return [String] The transcribed text
      #
      # @raise [Faraday::Error] On HTTP errors (wrapped as error string)
      # @raise [RuntimeError] On transcription failures (AssemblyAI)
      #
      # @example Local file
      #   tool.execute(audio: "/home/user/recording.mp3")
      #   # => "Hello, this is a test recording..."
      #
      # @example Remote URL
      #   tool.execute(audio: "https://storage.example.com/audio/meeting.wav")
      #   # => "Meeting transcript: We discussed the quarterly results..."
      def execute(audio:)
        @provider == "openai" ? transcribe_openai(audio) : transcribe_assemblyai(audio)
      rescue Faraday::Error => e
        "Error: #{e.message}"
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

      # Transcribes audio using AssemblyAI API.
      # @api private
      def transcribe_assemblyai(audio)
        conn = Faraday.new
        audio_url = audio.start_with?("http") ? audio : upload_to_assemblyai(conn, audio)

        response = conn.post("https://api.assemblyai.com/v2/transcript") do |req|
          req.headers["authorization"] = @api_key
          req.headers["content-type"] = "application/json"
          req.body = JSON.generate(audio_url: audio_url)
        end
        poll_transcription(conn, JSON.parse(response.body)["id"])
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

      # Polls AssemblyAI for transcription completion.
      # @api private
      def poll_transcription(conn, transcript_id)
        loop do
          response = conn.get("https://api.assemblyai.com/v2/transcript/#{transcript_id}") do |req|
            req.headers["authorization"] = @api_key
          end
          result = JSON.parse(response.body)
          case result["status"]
          when "completed" then return result["text"]
          when "error" then raise "Transcription failed: #{result["error"]}"
          else sleep(1)
          end
        end
      end
    end
  end

  # Re-export SpeechToTextTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::SpeechToTextTool
  SpeechToTextTool = Tools::SpeechToTextTool
end
