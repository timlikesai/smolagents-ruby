module Smolagents
  module Tools
    module SpeechToText
      # OpenAI Whisper transcription provider.
      #
      # Provides synchronous audio transcription via the OpenAI API.
      # Supports both local files and remote URLs.
      module OpenAI
        private

        # Transcribes audio using OpenAI Whisper API.
        # @param audio [String] Path or URL to audio file
        # @return [String] Transcribed text
        def transcribe_openai(audio)
          conn = build_multipart_connection
          audio_data = fetch_audio_data(audio)
          response = post_openai_transcription(conn, audio, audio_data)
          JSON.parse(response.body)["text"]
        end

        # Builds a multipart-enabled Faraday connection to OpenAI endpoint.
        #
        # @return [Faraday::Connection] Configured multipart connection
        def build_multipart_connection
          Faraday.new(url: @endpoint) { |f| f.request :multipart }
        end

        # Fetches audio data from local file or remote URL.
        #
        # @param audio [String] Local file path or HTTP(S) URL
        # @return [String] Audio data bytes
        def fetch_audio_data(audio)
          audio.start_with?("http") ? Faraday.new.get(audio).body : File.read(audio)
        end

        # Posts audio to OpenAI Whisper transcription API.
        #
        # @param conn [Faraday::Connection] Multipart connection
        # @param audio [String] Original audio path/URL for filename
        # @param audio_data [String] Raw audio bytes
        # @return [Faraday::Response] API response
        def post_openai_transcription(conn, audio, audio_data)
          conn.post do |req|
            req.headers["Authorization"] = "Bearer #{@api_key}"
            req.body = { file: build_file_part(audio, audio_data), model: @model }
          end
        end

        # Builds a multipart file part from audio data.
        #
        # @param audio [String] Original audio path for extracting filename
        # @param audio_data [String] Raw audio bytes
        # @return [Faraday::Multipart::FilePart] File part for multipart request
        def build_file_part(audio, audio_data)
          Faraday::Multipart::FilePart.new(StringIO.new(audio_data), "audio/mpeg", File.basename(audio))
        end
      end
    end
  end
end
