module Smolagents
  module Concerns
    # Hint generation for code execution feedback.
    #
    # Provides contextual hints to the model when it makes common mistakes,
    # helping guide it toward correct usage patterns.
    #
    # @example Detection patterns
    #   # Detects: final_answer = result (assignment instead of call)
    #   # Suggests: final_answer(answer: result)
    #
    #   # Detects: puts result (output instead of answer)
    #   # Suggests: final_answer(answer: result)
    #
    # @see CodeExecution For the main execution flow
    module CodeHints
      ASSIGNMENT_HINT = "[HINT: final_answer is a function, not a variable. " \
                        "Call: final_answer(answer: your_result)]".freeze
      PUTS_HINT = "[HINT: Use final_answer(answer: your_result) instead of puts to return your answer.]".freeze

      private

      # Add contextual hints based on code patterns.
      def with_code_hints(action_step, logs, code, final_answer)
        hints = collect_code_hints(code, final_answer)
        result = hints.any? ? "#{logs}\n#{hints.join("\n")}" : logs
        with_budget_reminder(action_step, result)
      end

      def collect_code_hints(code, final_answer)
        return [] unless code && !final_answer

        hints = []
        hints << ASSIGNMENT_HINT if code.match?(/final_answer\s*=/)
        hints << PUTS_HINT if code.match?(/\bputs\b/) && !code.match?(/\bfinal_answer\b/)
        hints
      end
    end
  end
end
