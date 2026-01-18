module Smolagents
  module Runtime
    module Memory
      # Observation masking for AgentMemory when over budget.
      #
      # Replaces old action step observations with placeholders to reduce token usage
      # while preserving recent observations for context continuity.
      module Masking
        ERROR_RECOVERY_GUIDANCE = <<~MSG.freeze
          Now let's retry: take care not to repeat previous errors!
          If you have retried several times, try a completely different approach.
        MSG

        private

        # Converts steps to messages, applying masking strategy when over budget.
        def steps_to_messages(summary_mode:)
          return unmasked_messages(summary_mode:) if config.full? || !over_budget?

          masked_messages(summary_mode:)
        end

        def unmasked_messages(summary_mode:)
          steps.flat_map { |step| step.to_messages(summary_mode:) }
        end

        def masked_messages(summary_mode:)
          preserve_set = build_preserve_set
          steps.each_with_index.flat_map { |step, idx| step_to_messages(step, idx, preserve_set, summary_mode:) }
        end

        def build_preserve_set
          action_indices = steps.each_with_index.filter_map { |s, i| i if s.is_a?(Types::ActionStep) }
          preserve_count = [config.preserve_recent, action_indices.size].min
          action_indices.last(preserve_count).to_set
        end

        def step_to_messages(step, idx, preserve_set, summary_mode:)
          return step.to_messages(summary_mode:) unless step.is_a?(Types::ActionStep)
          return step.to_messages(summary_mode:) if preserve_set.include?(idx)

          masked_step_to_messages(step, summary_mode:)
        end

        def masked_step_to_messages(step, summary_mode:)
          [
            masked_model_output(step, summary_mode:),
            masked_observation(step),
            masked_error(step)
          ].compact
        end

        def masked_model_output(step, summary_mode:)
          step.model_output_message unless summary_mode || step.model_output_message.nil?
        end

        def masked_observation(step)
          return unless step.observations && !step.observations.empty?

          Types::ChatMessage.tool_response(
            "Observation:\n#{Types::TOOL_OUTPUT_START}\n#{config.mask_placeholder}\n#{Types::TOOL_OUTPUT_END}"
          )
        end

        def masked_error(step)
          return unless step.error

          error_text = step.error.is_a?(String) ? step.error : step.error.message
          Types::ChatMessage.tool_response(
            "Error:\n#{Types::TOOL_OUTPUT_START}\n#{error_text}\n#{Types::TOOL_OUTPUT_END}\n#{ERROR_RECOVERY_GUIDANCE}"
          )
        end
      end
    end
  end
end
