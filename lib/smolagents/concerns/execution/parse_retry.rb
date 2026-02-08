module Smolagents
  module Concerns
    # Configurable parse retry when model produces non-code output.
    #
    # The most common failure mode from local GPU models is returning prose
    # without code blocks. This gives the model retries with guidance
    # before burning a full step on the parse failure.
    #
    # The retry counter persists across steps within a single run.
    # Configure via `.parse_max_retries(n)` on AgentBuilder (default: 2).
    #
    # Emits {Events::ParseRetryAttempted} on each retry for UI visibility.
    #
    # @see CodeExecution For integration with execute_step
    module ParseRetry
      DEFAULT_MAX_RETRIES = 2

      private

      # Initialize parse retry with configurable max.
      # @param max_retries [Integer] Maximum parse retries per run
      def initialize_parse_retry(max_retries: DEFAULT_MAX_RETRIES)
        @parse_max_retries = max_retries || DEFAULT_MAX_RETRIES
        @parse_retries = 0
      end

      # Reset parse retry counter (called at run start).
      def reset_parse_retries = (@parse_retries = 0)

      # Check if a parse retry is available and prepare for retry.
      #
      # @param action_step [ActionStep] Current step to annotate
      # @param result [Types::ExtractionResult] Failed extraction result
      # @return [Boolean] true if retry should be attempted
      def can_retry_parse?(action_step, result)
        @parse_retries ||= 0
        max = @parse_max_retries || DEFAULT_MAX_RETRIES
        return false if @parse_retries >= max
        return false unless retryable_parse_failure?(result)

        @parse_retries += 1
        action_step.error = nil
        action_step.observations = "[Parse error: #{result.message}. Respond with a ```ruby code block.]"
        emit_parse_retry(result, max)
        true
      end

      # Emit ParseRetryAttempted event for UI visibility.
      # @param result [Types::ExtractionResult] Failed extraction result
      # @param max [Integer] Maximum retries configured
      def emit_parse_retry(result, max)
        emit :parse_retry_attempted,
             retry_number: @parse_retries, max_retries: max,
             reason: result.reason, message: result.message
      end

      # Only retry when no code-like tags present (true format drift).
      # Skips retry when code tags exist but content wasn't recognized.
      def retryable_parse_failure?(result)
        return true if result.reason == :empty
        return false if result.original&.match?(/<code>|```/)

        true
      end
    end
  end
end
