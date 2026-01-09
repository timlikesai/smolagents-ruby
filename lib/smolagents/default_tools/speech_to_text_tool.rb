# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require "json"

module Smolagents
  module DefaultTools
    # Speech-to-text transcription tool.
    # Transcribes audio files using external APIs (OpenAI Whisper, AssemblyAI, etc.).
    class SpeechToTextTool < Tool
      self.tool_name = "transcriber"
      self.description = "Transcribes audio into text. Returns the transcribed text. " \
                        "Accepts audio file path or URL."
      self.inputs = {
        "audio" => {
          "type" => "string",
          "description" => "The audio file path or URL to transcribe."
        }
      }
      self.output_type = "string"

      # Initialize speech-to-text tool.
      #
      # @param provider [String] transcription provider ('openai' or 'assemblyai')
      # @param api_key [String, nil] API key (defaults to environment variable)
      # @param model [String] model to use for transcription
      # @raise [ArgumentError] if API key is missing
      def initialize(provider: "openai", api_key: nil, model: "whisper-1")
        super()
        @provider = provider
        @model = model

        case provider
        when "openai"
          api_key_env_name = "OPENAI_API_KEY"
          @endpoint = "https://api.openai.com/v1/audio/transcriptions"
        when "assemblyai"
          api_key_env_name = "ASSEMBLYAI_API_KEY"
          @endpoint = "https://api.assemblyai.com/v2/upload"
        else
          raise ArgumentError, "Unsupported provider: #{provider}"
        end

        @api_key = api_key || ENV[api_key_env_name]

        unless @api_key
          raise ArgumentError, "Missing API key. Set '#{api_key_env_name}' environment variable."
        end
      end

      # Transcribe audio file.
      #
      # @param audio [String] audio file path or URL
      # @return [String] transcribed text
      def forward(audio:)
        case @provider
        when "openai"
          transcribe_openai(audio)
        when "assemblyai"
          transcribe_assemblyai(audio)
        end
      rescue Faraday::Error => e
        "Error transcribing audio: #{e.message}"
      rescue StandardError => e
        "An unexpected error occurred: #{e.message}"
      end

      private

      # Transcribe using OpenAI Whisper API.
      #
      # @param audio [String] audio file path or URL
      # @return [String] transcribed text
      def transcribe_openai(audio)
        conn = Faraday.new(url: @endpoint) do |f|
          f.request :multipart
          f.adapter Faraday.default_adapter
        end

        # If it's a URL, download first
        audio_data = if audio.start_with?("http://", "https://")
                       download_audio(audio)
                     else
                       File.read(audio)
                     end

        payload = {
          file: Faraday::Multipart::FilePart.new(
            StringIO.new(audio_data),
            "audio/mpeg",
            File.basename(audio)
          ),
          model: @model
        }

        response = conn.post do |req|
          req.headers["Authorization"] = "Bearer #{@api_key}"
          req.body = payload
        end

        result = JSON.parse(response.body)
        result["text"]
      end

      # Transcribe using AssemblyAI API.
      #
      # @param audio [String] audio file path or URL
      # @return [String] transcribed text
      def transcribe_assemblyai(audio)
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end

        # Step 1: Upload audio
        audio_url = if audio.start_with?("http://", "https://")
                      audio
                    else
                      upload_to_assemblyai(conn, audio)
                    end

        # Step 2: Create transcription job
        response = conn.post("https://api.assemblyai.com/v2/transcript") do |req|
          req.headers["authorization"] = @api_key
          req.headers["content-type"] = "application/json"
          req.body = JSON.generate(audio_url: audio_url)
        end

        transcript_id = JSON.parse(response.body)["id"]

        # Step 3: Poll for completion
        poll_transcription(conn, transcript_id)
      end

      # Upload audio file to AssemblyAI.
      #
      # @param conn [Faraday::Connection] connection instance
      # @param file_path [String] local file path
      # @return [String] uploaded audio URL
      def upload_to_assemblyai(conn, file_path)
        response = conn.post("https://api.assemblyai.com/v2/upload") do |req|
          req.headers["authorization"] = @api_key
          req.body = File.read(file_path)
        end

        JSON.parse(response.body)["upload_url"]
      end

      # Poll AssemblyAI for transcription completion.
      #
      # @param conn [Faraday::Connection] connection instance
      # @param transcript_id [String] transcript ID
      # @return [String] transcribed text
      def poll_transcription(conn, transcript_id)
        url = "https://api.assemblyai.com/v2/transcript/#{transcript_id}"

        loop do
          response = conn.get(url) do |req|
            req.headers["authorization"] = @api_key
          end

          result = JSON.parse(response.body)

          case result["status"]
          when "completed"
            return result["text"]
          when "error"
            raise StandardError, "Transcription failed: #{result['error']}"
          else
            sleep(1)
          end
        end
      end

      # Download audio from URL.
      #
      # @param url [String] audio URL
      # @return [String] audio data
      def download_audio(url)
        conn = Faraday.new
        response = conn.get(url)
        response.body
      end
    end
  end
end
