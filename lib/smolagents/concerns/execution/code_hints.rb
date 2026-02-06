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
      PUTS_HINT = "[HINT: Use final_answer(answer: your_result) instead of puts/print to return your answer.]".freeze
      RETURN_HINT = "[HINT: Use final_answer(answer: value) instead of return to deliver your answer.]".freeze
      MISSING_FINAL_HINT = "[HINT: Don't forget to call final_answer(answer: result) with your result.]".freeze
      NIL_CHECK_HINT = "[HINT: Check for nil before accessing hash keys. " \
                       "Use: result && result[\"key\"] or result&.dig(\"key\")]".freeze
      HASH_EXTRACT_HINT = "[HINT: Tool results are hashes. Extract the value you need: " \
                          "result[\"key\"] not just result]".freeze
      SANDBOX_HINT = "[HINT: This operation is not available in the sandbox. " \
                     "Use the provided tools to accomplish your task.]".freeze

      UNDEFINED_VAR_PATTERN = /undefined local variable or method [`'](\w+)[`']/

      private

      # Add contextual hints based on code patterns.
      def with_code_hints(action_step, logs, code, final_answer)
        hints = collect_code_hints(code, final_answer, logs)
        result = hints.any? ? "#{logs}\n#{hints.join("\n")}" : logs
        with_budget_reminder(action_step, result)
      end

      def collect_code_hints(code, final_answer, logs = nil)
        return [] unless code && !final_answer

        hints = static_hints(code, logs)
        ivar_hint = instance_variable_hint(logs)
        hints << ivar_hint if ivar_hint
        hints
      end

      def static_hints(code, logs)
        [
          [ASSIGNMENT_HINT, assignment_error?(code)],
          [PUTS_HINT, print_without_answer?(code)],
          [RETURN_HINT, bare_return?(code)],
          [MISSING_FINAL_HINT, missing_final_answer?(code)],
          [NIL_CHECK_HINT, nil_access_error?(logs)],
          [HASH_EXTRACT_HINT, hash_conversion_error?(logs)],
          [SANDBOX_HINT, sandbox_error?(logs)]
        ].filter_map { |hint, match| hint if match }
      end

      def assignment_error?(code) = code.match?(/final_answer\s*=/)
      def print_without_answer?(code) = code.match?(/\b(?:puts|print)\b/) && !code.match?(/\bfinal_answer\b/)
      def bare_return?(code) = code.match?(/^\s*return\b/) && !code.match?(/\bfinal_answer\b/)
      def missing_final_answer?(code) = last_line_is_bare_value?(code) && !code.match?(/\bfinal_answer\b/)

      def last_line_is_bare_value?(code)
        last = code.strip.split("\n").last&.strip
        last&.match?(/\A[a-z_]\w*\z/) && !last.match?(/\A(?:end|else|nil|true|false|return|do)\z/)
      end

      def nil_access_error?(logs) = logs&.include?("undefined method") && logs.include?("nil:NilClass")
      def hash_conversion_error?(logs) = logs&.include?("no implicit conversion of Hash")
      def sandbox_error?(logs) = logs&.include?("in sandbox")

      # Detects when a local variable is used but an instance variable exists.
      # Common mistake: using `data` when `@data` was stored in a previous step.
      def instance_variable_hint(logs)
        return nil unless logs && (match = logs.match(UNDEFINED_VAR_PATTERN))

        var_name = match[1]
        return nil unless defined?(@state) && @state&.key?(var_name.to_sym)

        "[HINT: Did you mean @#{var_name}? Instance variables persist between steps. " \
          "Use @#{var_name} instead of #{var_name}]"
      end
    end
  end
end
