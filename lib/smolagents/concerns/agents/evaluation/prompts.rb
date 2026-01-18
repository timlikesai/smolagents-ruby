module Smolagents
  module Concerns
    module Evaluation
      # Prompt templates for evaluation phase.
      #
      # Token-efficient prompts for structured metacognition.
      module Prompts
        # System prompt for evaluation - minimal, focused.
        EVALUATION_SYSTEM = <<~PROMPT.strip.freeze
          You evaluate task completion. Be decisive. One line only.
        PROMPT

        # User prompt template - scoped context only.
        # Includes optional confidence for AgentPRM-style scoring.
        EVALUATION_PROMPT = <<~PROMPT.freeze
          TASK: %<task>s
          STEPS COMPLETED: %<step_count>d
          LAST RESULT: %<observation>s

          Is the task complete? Reply with EXACTLY one of:
          DONE: <the final answer>
          CONTINUE: <what's still needed>
          STUCK: <what's blocking>

          Optionally add confidence (0.0-1.0): CONFIDENCE: 0.8
        PROMPT

        def build_evaluation_messages(task, step_count, observation)
          [
            ChatMessage.system(EVALUATION_SYSTEM),
            ChatMessage.user(format(EVALUATION_PROMPT, task:, step_count:, observation:))
          ]
        end
      end
    end
  end
end
