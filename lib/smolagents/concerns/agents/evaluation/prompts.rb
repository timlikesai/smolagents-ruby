module Smolagents
  module Concerns
    module Evaluation
      # Prompt templates for evaluation phase.
      #
      # Token-efficient prompts for structured metacognition.
      module Prompts
        # System prompt for evaluation - minimal, focused.
        EVALUATION_SYSTEM = <<~PROMPT.strip.freeze
          You evaluate task completion. Be decisive. Extract specific information from results.
        PROMPT

        # User prompt template - scoped context only.
        # Includes optional confidence for AgentPRM-style scoring.
        EVALUATION_PROMPT = <<~PROMPT.freeze
          TASK: %<task>s
          STEPS COMPLETED: %<step_count>d
          BUDGET: %<budget>s
          LAST RESULT: %<observation>s

          Is the task complete? Reply with EXACTLY one of:
          DONE: <answer that fully addresses the task using information from LAST RESULT>
          CONTINUE: <what's still needed>
          STUCK: <what's blocking>

          IMPORTANT: DONE must include the actual answer with specific information, not just "task complete".
          If the task asks for links, include the links. If it asks for tutorials, list them.

          Optionally add confidence (0.0-1.0): CONFIDENCE: 0.8
        PROMPT

        def build_evaluation_messages(task, step_count, observation)
          budget = evaluation_budget_context(step_count)
          [
            ChatMessage.system(EVALUATION_SYSTEM),
            ChatMessage.user(format(EVALUATION_PROMPT, task:, step_count:, observation:, budget:))
          ]
        end

        private

        # Build budget context string for evaluation.
        def evaluation_budget_context(step_count)
          return "unlimited" unless @max_steps

          remaining = @max_steps - step_count
          return "LAST STEP" if remaining <= 0
          return "#{remaining} step#{"s" if remaining != 1} remaining" if remaining <= 3

          "#{remaining} steps remaining"
        end
      end
    end
  end
end
