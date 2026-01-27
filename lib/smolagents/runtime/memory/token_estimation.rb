module Smolagents
  module Runtime
    module Memory
      # Token estimation and budget tracking for AgentMemory.
      #
      # Provides heuristic-based token counting without expensive tokenization.
      module TokenEstimation
        # Approximate characters per token for estimation.
        CHARS_PER_TOKEN = 4

        # Estimates total token count for memory contents.
        # @return [Integer] Estimated token count
        def estimated_tokens
          total_chars = system_prompt.system_prompt.length
          steps.each { |step| total_chars += estimate_step_chars(step) }
          total_chars / CHARS_PER_TOKEN
        end

        # Checks if memory exceeds the configured token budget.
        # @return [Boolean] True if over budget
        def over_budget? = config.budget? && estimated_tokens > config.budget

        # Calculates remaining token capacity before hitting budget.
        # @return [Integer, nil] Remaining tokens, or nil if no budget configured
        def headroom
          config.budget? ? config.budget - estimated_tokens : nil
        end

        # Returns token usage as a percentage (0.0-1.0+).
        # Can exceed 1.0 if over budget.
        # @return [Float, nil] Usage percentage, or nil if no budget configured
        def token_usage_percent
          return nil unless config.budget?

          estimated_tokens.to_f / config.budget
        end

        private

        def estimate_step_chars(step)
          case step
          when Types::ActionStep then estimate_action_step_chars(step)
          when Types::TaskStep then step.task.to_s.length
          when Types::PlanningStep then step.plan.to_s.length + estimate_messages_chars(step.model_input_messages)
          when Types::FinalAnswerStep then step.output.to_s.length
          else 0
          end
        end

        def estimate_action_step_chars(step)
          (step.model_output_message&.content.to_s.length || 0) +
            step.observations.to_s.length +
            step.code_action.to_s.length +
            step.error.to_s.length
        end

        def estimate_messages_chars(messages)
          messages&.sum { |m| m.content.to_s.length } || 0
        end
      end
    end
  end
end
