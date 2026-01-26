module Smolagents
  module Tools
    module SpeechToText
      # Status checking for async transcription jobs.
      #
      # Handles polling and status response formatting for AssemblyAI jobs.
      module Status
        # Check status of an AssemblyAI transcription job.
        # Non-blocking - returns current status immediately.
        #
        # @param transcript_id [String] The transcript ID from TranscriptionJob
        # @return [Hash] Status hash with :status key and :text (if completed) or :error (if failed)
        def check_status(transcript_id)
          result = fetch_transcript_status(transcript_id)
          build_status_response(result, transcript_id)
        end

        private

        def fetch_transcript_status(transcript_id)
          conn = Faraday.new
          response = conn.get("#{Providers::ASSEMBLYAI_TRANSCRIPT_URL}/#{transcript_id}") do |req|
            req.headers["authorization"] = @api_key
          end
          JSON.parse(response.body)
        end

        def build_status_response(result, transcript_id)
          case result["status"]
          when "completed" then completed_status(result, transcript_id)
          when "error" then { status: "error", error: result["error"] }
          else { status: result["status"] }
          end
        end

        def completed_status(result, transcript_id)
          text = result["text"]
          notify_completion(transcript_id, text)
          { status: "completed", text: }
        end
      end
    end
  end
end
