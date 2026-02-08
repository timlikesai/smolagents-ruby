module Smolagents
  module Concerns
    # One free parse retry when model produces non-code output.
    #
    # The most common failure mode from local GPU models is returning prose
    # without code blocks. This gives the model ONE free retry with guidance
    # before burning a full step on the parse failure.
    #
    # The retry counter persists across steps within a single run.
    #
    # @see CodeExecution For integration with execute_step
    module ParseRetry
      MAX_PARSE_RETRIES = 1

      private

      # Reset parse retry counter (called at run start).
      def reset_parse_retries = (@parse_retries = 0)

      # Check if a parse retry is available and prepare for retry.
      #
      # @param action_step [ActionStep] Current step to annotate
      # @param result [Types::ExtractionResult] Failed extraction result
      # @return [Boolean] true if retry should be attempted
      def can_retry_parse?(action_step, result)
        @parse_retries ||= 0
        return false if @parse_retries >= MAX_PARSE_RETRIES
        return false unless retryable_parse_failure?(result)

        @parse_retries += 1
        action_step.error = nil
        action_step.observations = "[Parse error: #{result.message}. Respond with a ```ruby code block.]"
        true
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
