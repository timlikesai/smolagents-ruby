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
      # Compresses context if needed, then calls the model with current
      # memory converted to messages. Updates the action step with the
      # response and token usage.
      #
      # @param action_step [ActionStep, ActionStepBuilder] Step to update with model output
      # @return [ChatMessage] Model response
      # Heuristic: ~4 characters per token (matches TokenEstimation).
      CHARS_PER_TOKEN = 4

      def generate_code_response(action_step)
        compress_context_before_generation
        messages = write_memory_to_messages
        check_context_window(messages)
        response = with_generation_timeout(context: :step) { @model.generate(messages, stop_sequences: nil) }
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end

      private

      # Compress memory context if usage exceeds threshold.
      # Emits ContextCompressed event on successful compression.
      # @return [void]
      def compress_context_before_generation
        return unless @memory.respond_to?(:compress_if_needed!)

        summary = @memory.compress_if_needed!(model: @model)
        return unless summary

        emit :context_compressed,
             steps_compressed: summary.original_step_count,
             tokens_saved: summary.tokens_saved,
             new_usage_percent: @memory.token_usage_percent
      end

      # Emit warning when estimated tokens exceed model context window.
      # Soft check — does not block generation (estimation is heuristic).
      # @param messages [Array<ChatMessage>] Messages about to be sent
      # @return [void]
      def check_context_window(messages)
        window = @model.respond_to?(:context_window) && @model.context_window
        return unless window

        estimated = messages.sum { |m| (m.content.to_s.length.to_f / CHARS_PER_TOKEN).ceil }
        return unless estimated > window

        emit :context_window_exceeded,
             estimated_tokens: estimated,
             context_window: window,
             overflow_percent: ((estimated.to_f / window) * 100).round(1)
      end
    end
  end
end
