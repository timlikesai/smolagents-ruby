module Smolagents
  module Concerns
    # Extracts code blocks from model responses.
    #
    # Delegates to PatternMatching for the actual extraction logic.
    # Sets descriptive error messages when extraction fails.
    # Logs original response at debug level for troubleshooting.
    #
    # @example Extracting code
    #   result = extract_code_from_response(action_step, response)
    #   if result.success?
    #     execute(result.code)
    #   else
    #     # action_step.error is already set with specific reason
    #   end
    #
    # @see PatternMatching For code extraction patterns
    # @see Types::ExtractionResult For result structure
    module CodeParsing
      # Extract Ruby code from model response.
      #
      # Uses PatternMatching to find code blocks (```ruby...```).
      # Sets descriptive error on action_step if extraction fails.
      # Logs original response at debug level when extraction fails.
      #
      # @param action_step [ActionStep, ActionStepBuilder] Step to update on error
      # @param response [ChatMessage] Model response
      # @return [Types::ExtractionResult] Extraction result with code and failure context
      def extract_code_from_response(action_step, response)
        result = PatternMatching.extract_code(response.content)
        log_extraction_failure(result) if result.failure?
        action_step.error = result.message if result.failure?
        result
      end

      private

      # Log extraction failure with original response for debugging.
      def log_extraction_failure(result)
        return unless respond_to?(:logger, true) && logger

        original = result.original || "(empty)"
        truncated = original.length > 200 ? "#{original[0, 200]}..." : original
        logger.debug("Code extraction failed (#{result.reason}): #{truncated}")
      end
    end
  end
end
