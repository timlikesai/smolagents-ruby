module Smolagents
  module Types
    # Immutable snapshot of an API failure for debugging.
    #
    # Captures the full context of a model call failure: what was sent, what came
    # back, and which step it happened on. Essential for diagnosing local GPU
    # model issues (CUDA OOM, context overflow, malformed JSON).
    #
    # @example Creating from an error
    #   snapshot = FailureSnapshot.capture(
    #     model_id: "gemma-3n",
    #     error: RuntimeError.new("Connection refused"),
    #     request_summary: "POST /v1/chat/completions (2048 tokens)",
    #     response_summary: "500 Internal Server Error",
    #     step_number: 3
    #   )
    #
    # @see Concerns::Resilience::FailureCapture For the concern that collects these
    FailureSnapshot = Data.define(
      :timestamp, :model_id, :error_class, :error_message,
      :request_summary, :response_summary, :step_number
    ) do
      include TypeSupport::Deconstructable

      # Factory method to capture a failure snapshot.
      #
      # @param model_id [String] Model identifier
      # @param error [Exception] The exception that occurred
      # @param request_summary [String, nil] Truncated request context
      # @param response_summary [String, nil] Truncated response context
      # @param step_number [Integer, nil] Agent step where failure occurred
      # @return [FailureSnapshot]
      def self.capture(model_id:, error:, request_summary: nil, response_summary: nil, step_number: nil)
        new(
          timestamp: Time.now,
          model_id:,
          error_class: error.class.name,
          error_message: truncate(error.message, 500),
          request_summary: truncate(request_summary, 500),
          response_summary: truncate(response_summary, 500),
          step_number:
        )
      end

      # Human-readable one-line summary.
      # @return [String]
      def summary
        parts = ["[#{timestamp_short}]", "#{error_class}: #{error_message}"]
        parts << "(step #{step_number})" if step_number
        parts << "model=#{model_id}" if model_id
        parts.join(" ")
      end

      # Short timestamp for display.
      # @return [String]
      def timestamp_short = timestamp.strftime("%H:%M:%S")

      # Whether this snapshot has request context.
      # @return [Boolean]
      def request? = !request_summary.nil?

      # Whether this snapshot has response context.
      # @return [Boolean]
      def response? = !response_summary.nil?

      # Serializable hash representation.
      # @return [Hash]
      def to_h
        {
          timestamp: timestamp.iso8601,
          model_id:, error_class:, error_message:,
          request_summary:, response_summary:, step_number:
        }
      end

      # @api private
      def self.truncate(str, max)
        return nil if str.nil?

        str.length > max ? "#{str[0, max - 3]}..." : str
      end
    end
  end
end
