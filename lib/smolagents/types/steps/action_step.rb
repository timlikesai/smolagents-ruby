module Smolagents
  module Types
    # Guidance text for error recovery in action steps.
    ACTION_STEP_ERROR_GUIDANCE = <<~MSG.freeze
      Now let's retry: take care not to repeat previous errors!
      If you have retried several times, try a completely different approach.
    MSG

    # Immutable step representing a single action in the ReAct loop.
    # Captures model output, tool calls, observations, timing, and errors.
    #
    # @see ActionStepBuilder Mutable builder for constructing action steps
    ActionStep = Data.define(
      :step_number, :timing, :model_output_message, :tool_calls, :error,
      :code_action, :observations, :observations_images, :action_output, :token_usage, :is_final_answer,
      :trace_id, :parent_trace_id
    ) do
      def initialize(step_number:, timing: nil, model_output_message: nil, tool_calls: nil, error: nil,
                     code_action: nil, observations: nil, observations_images: nil, action_output: nil,
                     token_usage: nil, is_final_answer: false, trace_id: nil, parent_trace_id: nil)
        super
      end

      # @return [Hash] Step data as a hash
      def to_h = core_fields.merge(execution_fields).merge(trace_fields).compact

      # @param summary_mode [Boolean] Use condensed format
      # @return [Array<ChatMessage>] Messages from this step
      def to_messages(summary_mode: false)
        [model_output_message_for(summary_mode), observation_message, error_message_with_guidance].compact
      end

      # @return [String, nil] Reasoning content or nil if not present
      def reasoning_content = extract_reasoning_from_message || extract_reasoning_from_raw

      # @return [Boolean] True if reasoning_content is present and non-empty
      def reasoning? = reasoning_content&.then { !it.empty? } || false

      # @return [Boolean] True if this step contains the final answer
      def final_answer? = is_final_answer || false

      # @return [String] Observation text suitable for evaluation
      def evaluation_observation = observations || action_output.to_s

      # @return [Hash] All fields as a hash for pattern matching
      def deconstruct_keys(_keys) = to_h

      private

      def core_fields = { step_number:, timing: timing&.to_h, error: normalize_error(error) }

      def execution_fields
        { tool_calls: tool_calls&.map(&:to_h), code_action:, observations:,
          observations_images: observations_images&.size, action_output:, token_usage: token_usage&.to_h }
      end

      def trace_fields = { is_final_answer:, trace_id:, parent_trace_id:, reasoning_content: normalize_reasoning }

      def model_output_message_for(summary_mode)
        model_output_message unless summary_mode || model_output_message.nil?
      end

      def observation_message
        return if observations.nil? || observations.empty?

        ChatMessage.tool_response("Observation:\n#{observations}")
      end

      def error_message_with_guidance
        return unless error

        error_text = error.is_a?(String) ? error : error.message
        ChatMessage.tool_response("Error:\n#{error_text}\n#{ACTION_STEP_ERROR_GUIDANCE}")
      end

      def normalize_error(err) = err.is_a?(String) ? err : err&.message

      def normalize_reasoning = reasoning_content&.then { it.empty? ? nil : it }

      def extract_reasoning_from_message
        return unless model_output_message.respond_to?(:reasoning_content)

        model_output_message.reasoning_content
      end

      def extract_reasoning_from_raw
        return unless model_output_message.respond_to?(:raw)

        raw = model_output_message.raw
        return unless raw.is_a?(Hash)

        first_message = raw.dig("choices", 0, "message") || raw.dig(:choices, 0, :message)
        return unless first_message.is_a?(Hash)

        first_message.values_at("reasoning_content", :reasoning_content, "reasoning", :reasoning).compact.first
      end
    end
  end
end
