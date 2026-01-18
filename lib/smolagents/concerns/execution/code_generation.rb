module Smolagents
  module Concerns
    # Generates code responses from the model.
    #
    # Handles calling the model with the current memory state
    # and capturing the response with token usage.
    #
    # @example Generating a code response
    #   response = generate_code_response(action_step)
    #   # action_step now has model_output_message and token_usage set
    #
    # @see CodeParsing For extracting code from responses
    # @see CodeExecution For the full execution pipeline
    module CodeGeneration
      # Generate code response from model.
      #
      # Calls the model with current memory converted to messages.
      # Updates the action step with the response and token usage.
      #
      # @param action_step [ActionStep, ActionStepBuilder] Step to update with model output
      # @return [ChatMessage] Model response
      def generate_code_response(action_step)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end
    end
  end
end
