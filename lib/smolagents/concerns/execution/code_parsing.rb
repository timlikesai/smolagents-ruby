module Smolagents
  module Concerns
    # Extracts code blocks from model responses.
    #
    # Delegates to PatternMatching for the actual extraction logic.
    # Handles error state when no code block is found.
    #
    # @example Extracting code
    #   code = extract_code_from_response(action_step, response)
    #   if code
    #     # execute the code
    #   else
    #     # action_step.error is set
    #   end
    #
    # @see PatternMatching For code extraction patterns
    # @see CodeGeneration For generating model responses
    module CodeParsing
      # Extract Ruby code from model response.
      #
      # Uses PatternMatching to find code blocks (```ruby...```).
      # Sets error on action_step if no code found.
      #
      # @param action_step [ActionStep, ActionStepBuilder] Step to update on error
      # @param response [ChatMessage] Model response
      # @return [String, nil] Extracted code or nil
      def extract_code_from_response(action_step, response)
        code = PatternMatching.extract_code(response.content)
        action_step.error = "No code block found in response" unless code
        code
      end
    end
  end
end
