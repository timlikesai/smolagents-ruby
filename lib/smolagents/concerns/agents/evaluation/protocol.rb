module Smolagents
  module Concerns
    module Evaluation
      # Protocol for evaluation: prompts and step interface.
      #
      # Combines prompt templates with step protocol methods for a
      # unified evaluation interface. Steps passed to evaluation can
      # implement:
      # - +evaluation_observation+ - String observation text
      # - +final_answer?+ - Boolean predicate method
      module Protocol
        # System prompt for evaluation - minimal, focused.
        EVALUATION_SYSTEM = <<~PROMPT.strip.freeze
          You evaluate task completion. Be decisive. Copy exact values from results - never reformat.
        PROMPT

        # User prompt template - scoped context only.
        # Includes optional confidence for AgentPRM-style scoring.
        EVALUATION_PROMPT = <<~PROMPT.freeze
          TASK: %<task>s
          STEPS COMPLETED: %<step_count>d
          BUDGET: %<budget>s
          LAST RESULT: %<observation>s

          Is the task complete? Reply with EXACTLY one of:
          DONE: <the exact answer from LAST RESULT - copy values verbatim, no reformatting>
          CONTINUE: <what's still needed>
          STUCK: <what's blocking>

          CRITICAL: When answering DONE, preserve the EXACT format from LAST RESULT.
          - If result is "hihihi", answer "hihihi" NOT "Hi hi hi"
          - If result is "user42@example.com", answer that exact string
          - Do NOT add spaces, change capitalization, or rephrase values

          Optionally add confidence (0.0-1.0): CONFIDENCE: 0.8
        PROMPT

        # Build evaluation messages for the model.
        # @param task [String] The original task
        # @param step_count [Integer] Number of steps completed
        # @param observation [String] Last observation text
        # @return [Array<ChatMessage>] Messages for evaluation
        def build_evaluation_messages(task, step_count, observation)
          budget = evaluation_budget_context(step_count)
          [
            ChatMessage.system(EVALUATION_SYSTEM),
            ChatMessage.user(format(EVALUATION_PROMPT, task:, step_count:, observation:, budget:))
          ]
        end

        # Extracts observation text from step using the EvaluableStep protocol.
        #
        # Steps implementing +evaluation_observation+ get that value directly.
        # Falls back to +observations+ or +action_output+ for duck typing.
        #
        # @param step [#evaluation_observation, #observations, #action_output] The step
        # @return [String] Observation text (truncated to 1500 chars to capture links)
        def extract_observation(step)
          obs = extract_raw_observation(step)
          obs.to_s.slice(0, 1500) # Allow enough for links and descriptions
        end

        # Checks if step is a final answer using the EvaluableStep protocol.
        #
        # @param step [#final_answer?] The step to check
        # @return [Boolean] True if step represents task completion
        def step_is_final_answer?(step) = step.respond_to?(:final_answer?) && step.final_answer?

        private

        # Build budget context string for evaluation.
        def evaluation_budget_context(step_count)
          return "unlimited" unless @max_steps

          remaining = @max_steps - step_count
          return "LAST STEP" if remaining <= 0
          return "#{remaining} step#{"s" if remaining != 1} remaining" if remaining <= 3

          "#{remaining} steps remaining"
        end

        def extract_raw_observation(step)
          if step.respond_to?(:evaluation_observation)
            step.evaluation_observation
          elsif step.respond_to?(:observations)
            step.observations || step.action_output.to_s
          else
            step.to_s
          end
        end
      end
    end
  end
end
