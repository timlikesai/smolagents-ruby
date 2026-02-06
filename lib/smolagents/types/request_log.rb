# Request log type for model call tracking.

module Smolagents
  module Types
    # Immutable record of a model generation request.
    #
    # Captures the essential details of an LLM API call for debugging,
    # cost analysis, and auditing. Built from model events.
    #
    # @example Accessing request logs
    #   model.request_logs.each do |log|
    #     puts "#{log.model_id}: #{log.token_usage[:total]} tokens in #{log.duration_ms}ms"
    #   end
    #
    # @see Models::Model::RequestLogging Concern that generates these
    RequestLog = Data.define(
      :id,
      :model_id,
      :timestamp,
      :duration_ms,
      :message_count,
      :token_usage,
      :outcome,
      :has_tool_calls,
      :temperature
    ) do
      # Creates a RequestLog from model generation events.
      #
      # @param requested [Events::ModelGenerateRequested] Request event
      # @param completed [Events::ModelGenerateCompleted] Completion event
      # @return [RequestLog]
      def self.from_events(requested, completed)
        new(id: completed.id, model_id: completed.model_id, timestamp: requested.created_at,
            duration_ms: completed.duration_ms, message_count: requested.message_count,
            token_usage: completed.token_usage, outcome: completed.outcome,
            has_tool_calls: completed.has_tool_calls, temperature: requested.temperature)
      end

      include TypeSupport::StatePredicates

      state_predicates :outcome, success: :success, error: :error

      # Total tokens used (input + output).
      # @return [Integer, nil]
      def total_tokens
        return nil unless token_usage

        (token_usage[:input_tokens] || 0) + (token_usage[:output_tokens] || 0)
      end

      # Input tokens used.
      # @return [Integer, nil]
      def input_tokens = token_usage&.dig(:input_tokens)

      # Output tokens used.
      # @return [Integer, nil]
      def output_tokens = token_usage&.dig(:output_tokens)

      # Tokens per millisecond (throughput).
      # @return [Float, nil]
      def tokens_per_ms
        return nil unless total_tokens && duration_ms&.positive?

        total_tokens.to_f / duration_ms
      end

      # Serializes to hash for JSON output.
      # @return [Hash]
      def as_json
        {
          id:, model_id:, timestamp: timestamp.iso8601,
          duration_ms:, message_count:, token_usage:,
          outcome:, has_tool_calls:, temperature:
        }
      end
    end
  end
end
