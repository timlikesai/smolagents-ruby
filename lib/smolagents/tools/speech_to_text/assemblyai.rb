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

        def resolve_audio_url(conn, audio)
          audio.start_with?("http") ? audio : upload_to_assemblyai(conn, audio)
        end

        def post_assemblyai_transcription(conn, audio_url)
          response = conn.post(Providers::ASSEMBLYAI_TRANSCRIPT_URL) do |req|
            req.headers["authorization"] = @api_key
            req.headers["content-type"] = "application/json"
            req.body = JSON.generate(audio_url:)
          end
          JSON.parse(response.body)
        end

        def build_transcription_job(result, audio_url)
          Types::TranscriptionJob.new(
            transcript_id: result["id"],
            status: result["status"],
            audio_url:,
            created_at: Time.now
          )
        end

        # Uploads a local file to AssemblyAI's upload endpoint.
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
