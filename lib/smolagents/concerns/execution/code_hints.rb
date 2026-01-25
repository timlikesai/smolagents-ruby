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
        hints << final_answer_assignment_hint if code.match?(/final_answer\s*=/)
        hints << puts_instead_of_final_hint if code.match?(/\bputs\b/) && !code.match?(/\bfinal_answer\b/)
        hints
      end

      def final_answer_assignment_hint
        "[HINT: final_answer is a function, not a variable. Call: final_answer(answer: your_result)]"
      end

      def puts_instead_of_final_hint
        "[HINT: Use final_answer(answer: your_result) instead of puts to return your answer.]"
      end
    end
  end
end
