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
      NIL_CHECK_HINT = "[HINT: Check for nil before accessing hash keys. " \
                       "Use: result && result[\"key\"] or result&.dig(\"key\")]".freeze
      HASH_EXTRACT_HINT = "[HINT: Tool results are hashes. Extract the value you need: " \
                          "result[\"key\"] not just result]".freeze

      private

      # Add contextual hints based on code patterns.
      def with_code_hints(action_step, logs, code, final_answer)
        hints = collect_code_hints(code, final_answer, logs)
        result = hints.any? ? "#{logs}\n#{hints.join("\n")}" : logs
        with_budget_reminder(action_step, result)
      end

      def collect_code_hints(code, final_answer, logs = nil)
        return [] unless code && !final_answer

        [
          [ASSIGNMENT_HINT, assignment_error?(code)],
          [PUTS_HINT, puts_without_answer?(code)],
          [NIL_CHECK_HINT, nil_access_error?(logs)],
          [HASH_EXTRACT_HINT, hash_conversion_error?(logs)]
        ].filter_map { |hint, match| hint if match }
      end

      def assignment_error?(code) = code.match?(/final_answer\s*=/)
      def puts_without_answer?(code) = code.match?(/\bputs\b/) && !code.match?(/\bfinal_answer\b/)
      def nil_access_error?(logs) = logs&.include?("undefined method") && logs.include?("nil:NilClass")
      def hash_conversion_error?(logs) = logs&.include?("no implicit conversion of Hash")
    end
  end
end
