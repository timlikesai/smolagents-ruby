module Smolagents
  module Tools
    module SpeechToText
      # AssemblyAI transcription provider.
      #
      # Provides async audio transcription via the AssemblyAI API.
      # Returns a TranscriptionJob that can be polled for completion.
      module AssemblyAI
        private

        # Starts async transcription using AssemblyAI API.
        # @param audio [String] Path or URL to audio file
        # @return [Types::TranscriptionJob] Job to poll for completion
        def transcribe_assemblyai(audio)
          conn = Faraday.new
          audio_url = resolve_audio_url(conn, audio)
          result = post_assemblyai_transcription(conn, audio_url)
          build_transcription_job(result, audio_url)
        end

        # Resolves audio to a URL, uploading local files if necessary.
        #
        # @param conn [Faraday::Connection] HTTP connection
        # @param audio [String] Local file path or HTTP(S) URL
        # @return [String] Remote URL accessible by AssemblyAI
        def resolve_audio_url(conn, audio)
          audio.start_with?("http") ? audio : upload_to_assemblyai(conn, audio)
        end

        # Posts audio URL to AssemblyAI transcription endpoint.
        #
        # @param conn [Faraday::Connection] HTTP connection
        # @param audio_url [String] Remote audio URL
        # @return [Hash] Parsed API response with transcript ID and status
        def post_assemblyai_transcription(conn, audio_url)
          response = conn.post(Providers::ASSEMBLYAI_TRANSCRIPT_URL) do |req|
            req.headers["authorization"] = @api_key
            req.headers["content-type"] = "application/json"
            req.body = JSON.generate(audio_url:)
          end
          JSON.parse(response.body)
        end

        # Builds a TranscriptionJob from AssemblyAI API response.
        #
        # @param result [Hash] API response data
        # @param audio_url [String] The audio URL used
        # @return [Types::TranscriptionJob] Job object for polling
        def build_transcription_job(result, audio_url)
          Types::TranscriptionJob.new(
            transcript_id: result["id"],
            status: result["status"],
            audio_url:,
            created_at: Time.now
          )
        end

        # Uploads a local file to AssemblyAI's upload endpoint.
        #
        # @param conn [Faraday::Connection] HTTP connection
        # @param file_path [String] Local audio file path
        # @return [String] Remote URL for uploaded audio
        def upload_to_assemblyai(conn, file_path)
          response = conn.post(Providers::ASSEMBLYAI_UPLOAD_URL) do |req|
            req.headers["authorization"] = @api_key
            req.body = File.read(file_path)
          end
          JSON.parse(response.body)["upload_url"]
        end
      end
    end
  end
end
