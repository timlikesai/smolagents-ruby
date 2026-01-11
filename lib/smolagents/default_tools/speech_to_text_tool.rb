# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require "json"

module Smolagents
  module DefaultTools
    # Speech-to-text transcription tool using OpenAI Whisper or AssemblyAI.
    class SpeechToTextTool < Tool
      include Concerns::ApiKeyManagement

      self.tool_name = "speech_to_text"
      self.description = "Transcribes audio into text. Accepts audio file path or URL."
      self.inputs = { audio: { type: "string", description: "The audio file path or URL to transcribe." } }
      self.output_type = "string"

      PROVIDERS = {
        "openai" => { env: "OPENAI_API_KEY", endpoint: "https://api.openai.com/v1/audio/transcriptions" },
        "assemblyai" => { env: "ASSEMBLYAI_API_KEY", endpoint: "https://api.assemblyai.com/v2/upload" }
      }.freeze

      def initialize(provider: "openai", api_key: nil, model: "whisper-1")
        super()
        @provider = provider
        @model = model
        config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
        @endpoint = config[:endpoint]
      end

      def forward(audio:)
        @provider == "openai" ? transcribe_openai(audio) : transcribe_assemblyai(audio)
      rescue Faraday::Error => e
        "Error transcribing audio: #{e.message}"
      rescue StandardError => e
        "An unexpected error occurred: #{e.message}"
      end

      private

      def transcribe_openai(audio)
        conn = Faraday.new(url: @endpoint) { |f| f.request :multipart }
        audio_data = audio.start_with?("http://", "https://") ? Faraday.new.get(audio).body : File.read(audio)

        response = conn.post do |req|
          req.headers["Authorization"] = "Bearer #{@api_key}"
          req.body = {
            file: Faraday::Multipart::FilePart.new(StringIO.new(audio_data), "audio/mpeg", File.basename(audio)),
            model: @model
          }
        end
        JSON.parse(response.body)["text"]
      end

      def transcribe_assemblyai(audio)
        conn = Faraday.new
        audio_url = audio.start_with?("http://", "https://") ? audio : upload_to_assemblyai(conn, audio)

        response = conn.post("https://api.assemblyai.com/v2/transcript") do |req|
          req.headers["authorization"] = @api_key
          req.headers["content-type"] = "application/json"
          req.body = JSON.generate(audio_url: audio_url)
        end

        poll_transcription(conn, JSON.parse(response.body)["id"])
      end

      def upload_to_assemblyai(conn, file_path)
        response = conn.post("https://api.assemblyai.com/v2/upload") do |req|
          req.headers["authorization"] = @api_key
          req.body = File.read(file_path)
        end
        JSON.parse(response.body)["upload_url"]
      end

      def poll_transcription(conn, transcript_id)
        loop do
          response = conn.get("https://api.assemblyai.com/v2/transcript/#{transcript_id}") do |req|
            req.headers["authorization"] = @api_key
          end
          result = JSON.parse(response.body)
          case result["status"]
          when "completed" then return result["text"]
          when "error" then raise StandardError, "Transcription failed: #{result["error"]}"
          else sleep(1)
          end
        end
      end
    end
  end
end
