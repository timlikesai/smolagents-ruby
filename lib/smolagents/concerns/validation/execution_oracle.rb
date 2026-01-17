module Smolagents
  module Concerns
    # Execution Feedback Oracle for small model validation.
    #
    # Research shows that small models cannot self-correct reasoning errors,
    # but CAN correct based on external feedback. This oracle parses execution
    # results and provides structured, actionable feedback.
    #
    # @see https://arxiv.org/abs/2310.01798 "Large Language Models Cannot Self-Correct"
    #
    # @example Basic usage
    #   include ExecutionOracle
    #
    #   feedback = analyze_execution(result, code)
    #   if feedback.actionable?
    #     inject_feedback(feedback)
    #   end
    #
    # @example Pattern matching on feedback
    #   case analyze_execution(result, code)
    #   in ExecutionFeedback[category: :syntax_error, suggestion:]
    #     "Fix syntax: #{suggestion}"
    #   in ExecutionFeedback[category: :name_error, undefined_name:]
    #     "Variable '#{undefined_name}' is not defined"
    #   in ExecutionFeedback[success?: true]
    #     "Execution succeeded"
    #   end
    module ExecutionOracle
      # Error categories for classification.
      # Each category has specific parsing and fix strategies.
      ERROR_CATEGORIES = %i[
        success
        syntax_error
        name_error
        type_error
        argument_error
        no_method_error
        tool_error
        timeout
        memory_limit
        operation_limit
        runtime_error
      ].freeze

      # Patterns for extracting information from error messages.
      ERROR_PATTERNS = {
        syntax_error: /syntax error.*?(?:unexpected (\S+)|expecting (\S+))/i,
        name_error: /undefined (?:local variable or method|constant) [`'](\w+)'/i,
        no_method_error: /undefined method [`'](\w+)'(?: for (?:an instance of )?(\S+))?/i,
        type_error: /(?:no implicit conversion of (\S+) into (\S+)|(\S+) can't be coerced into (\S+))/i,
        argument_error: /wrong number of arguments \(given (\d+), expected (\d+(?:\.\.\d+)?)\)/i,
        tool_not_found: /Tool [`'](\w+)' not found/i,
        timeout: /execution timed out|timeout/i,
        memory_limit: /memory limit|out of memory/i,
        operation_limit: /operation limit|too many operations/i
      }.freeze

      # Structured feedback from execution analysis.
      #
      # @!attribute [r] category
      #   @return [Symbol] Error category from ERROR_CATEGORIES
      # @!attribute [r] message
      #   @return [String] Original error message
      # @!attribute [r] suggestion
      #   @return [String] Actionable fix suggestion
      # @!attribute [r] location
      #   @return [Hash, nil] Error location {line:, column:}
      # @!attribute [r] details
      #   @return [Hash] Category-specific parsed details
      # @!attribute [r] confidence
      #   @return [Float] Confidence in the suggestion (0.0-1.0)
      ExecutionFeedback = Data.define(
        :category,
        :message,
        :suggestion,
        :location,
        :details,
        :confidence
      ) do
        # Whether execution succeeded.
        # @return [Boolean]
        def success? = category == :success

        # Whether execution failed.
        # @return [Boolean]
        def failure? = !success?

        # Whether we have an actionable suggestion.
        # @return [Boolean]
        def actionable? = failure? && suggestion && !suggestion.empty?

        # Whether this is a syntax error (fixable without re-reasoning).
        # @return [Boolean]
        def syntax_fixable? = category == :syntax_error

        # Whether this requires a different approach (not just fixing syntax).
        # @return [Boolean]
        def needs_new_approach?
          %i[tool_error timeout memory_limit operation_limit].include?(category)
        end

        # Format as observation for agent.
        # @return [String]
        def to_observation
          return "Execution successful." if success?

          parts = ["Error [#{category}]: #{message}"]
          parts << "Location: line #{location[:line]}" if location&.dig(:line)
          parts << "Fix: #{suggestion}" if suggestion
          parts.join("\n")
        end

        class << self
          # Create success feedback.
          # @return [ExecutionFeedback]
          def success(output: nil)
            new(
              category: :success,
              message: output.to_s,
              suggestion: nil,
              location: nil,
              details: { output: },
              confidence: 1.0
            )
          end

          # Create failure feedback with parsed details.
          # @param category [Symbol] Error category
          # @param message [String] Error message
          # @param suggestion [String] Fix suggestion
          # @param location [Hash, nil] Error location
          # @param details [Hash] Additional details
          # @param confidence [Float] Suggestion confidence
          # @return [ExecutionFeedback]
          def failure(category:, message:, suggestion:, location: nil, details: {}, confidence: 0.7)
            new(category:, message:, suggestion:, location:, details:, confidence:)
          end
        end
      end

      # Analyzes execution result and returns structured feedback.
      #
      # This is the main entry point for the oracle. It parses the execution
      # result and generates actionable feedback for the agent.
      #
      # @param result [ExecutionResult] The execution result to analyze
      # @param code [String, nil] The code that was executed
      # @return [ExecutionFeedback] Structured feedback
      def analyze_execution(result, code = nil)
        return ExecutionFeedback.success(output: result.output) if result.success?

        error_message = result.error.to_s
        category = classify_error(error_message)
        details = parse_error_details(category, error_message)
        location = extract_location(error_message, code)
        suggestion = generate_suggestion(category, details, code)
        confidence = calculate_confidence(category, details)

        ExecutionFeedback.failure(
          category:,
          message: error_message,
          suggestion:,
          location:,
          details:,
          confidence:
        )
      end

      # Classifies an error message into a category.
      #
      # @param message [String] Error message
      # @return [Symbol] Error category
      def classify_error(message)
        return :syntax_error if message.include?("syntax error")
        return :name_error if message =~ ERROR_PATTERNS[:name_error]
        return :no_method_error if message =~ ERROR_PATTERNS[:no_method_error]
        return :type_error if message =~ ERROR_PATTERNS[:type_error]
        return :argument_error if message =~ ERROR_PATTERNS[:argument_error]
        return :tool_error if message =~ ERROR_PATTERNS[:tool_not_found]
        return :timeout if message =~ ERROR_PATTERNS[:timeout]
        return :memory_limit if message =~ ERROR_PATTERNS[:memory_limit]
        return :operation_limit if message =~ ERROR_PATTERNS[:operation_limit]

        :runtime_error
      end

      private

      def parse_error_details(category, message)
        case category
        when :name_error
          parse_name_error(message)
        when :no_method_error
          parse_no_method_error(message)
        when :type_error
          parse_type_error(message)
        when :argument_error
          parse_argument_error(message)
        when :tool_error
          parse_tool_error(message)
        when :syntax_error
          parse_syntax_error(message)
        else
          {}
        end
      end

      def parse_name_error(message)
        return {} unless message =~ ERROR_PATTERNS[:name_error]

        { undefined_name: ::Regexp.last_match(1) }
      end

      def parse_no_method_error(message)
        return {} unless message =~ ERROR_PATTERNS[:no_method_error]

        {
          undefined_method: ::Regexp.last_match(1),
          receiver_class: ::Regexp.last_match(2)
        }.compact
      end

      def parse_type_error(message)
        return {} unless message =~ ERROR_PATTERNS[:type_error]

        {
          from_type: ::Regexp.last_match(1) || ::Regexp.last_match(3),
          to_type: ::Regexp.last_match(2) || ::Regexp.last_match(4)
        }.compact
      end

      def parse_argument_error(message)
        return {} unless message =~ ERROR_PATTERNS[:argument_error]

        {
          given: ::Regexp.last_match(1).to_i,
          expected: ::Regexp.last_match(2)
        }
      end

      def parse_tool_error(message)
        return {} unless message =~ ERROR_PATTERNS[:tool_not_found]

        { tool_name: ::Regexp.last_match(1) }
      end

      def parse_syntax_error(message)
        details = {}
        details[:unexpected] = ::Regexp.last_match(1) if message =~ /unexpected (\S+)/
        details[:expecting] = ::Regexp.last_match(1) if message =~ /expecting (\S+)/
        details
      end

      def extract_location(message, _code)
        # Extract line number from error message
        return nil unless message =~ /:(\d+):/

        { line: ::Regexp.last_match(1).to_i }
      end

      def generate_suggestion(category, details, code)
        case category
        when :syntax_error
          syntax_suggestion(details)
        when :name_error
          name_error_suggestion(details, code)
        when :no_method_error
          no_method_suggestion(details)
        when :type_error
          type_error_suggestion(details)
        when :argument_error
          argument_error_suggestion(details)
        when :tool_error
          tool_error_suggestion(details)
        when :timeout
          "Simplify the code or break into smaller steps."
        when :memory_limit
          "Reduce data size or process in smaller batches."
        when :operation_limit
          "Reduce loop iterations or use more efficient algorithms."
        else
          "Check the error message and try a different approach."
        end
      end

      def syntax_suggestion(details)
        parts = []
        parts << "Remove or fix '#{details[:unexpected]}'" if details[:unexpected]
        parts << "Add '#{details[:expecting]}'" if details[:expecting]
        parts << "Check brackets, quotes, and keyword pairs (do/end, if/end)" if parts.empty?
        parts.join(". ")
      end

      def name_error_suggestion(details, code)
        name = details[:undefined_name]
        return "Check variable/method name spelling." unless name

        # Try to find similar names in code
        similar = find_similar_names(name, code)
        if similar.any?
          "Did you mean: #{similar.join(', ')}?"
        else
          "Define '#{name}' before using it, or check spelling."
        end
      end

      def no_method_suggestion(details)
        method = details[:undefined_method]
        receiver = details[:receiver_class]

        if receiver
          "#{receiver} doesn't have method '#{method}'. Check available methods."
        else
          "Method '#{method}' doesn't exist. Check spelling or use a different approach."
        end
      end

      def type_error_suggestion(details)
        from = details[:from_type]
        to = details[:to_type]

        if from && to
          "Convert #{from} to #{to} explicitly (e.g., .to_s, .to_i, .to_f)."
        else
          "Check types and add explicit conversions where needed."
        end
      end

      def argument_error_suggestion(details)
        given = details[:given]
        expected = details[:expected]

        if given && expected
          "Pass #{expected} argument(s) instead of #{given}."
        else
          "Check the method signature and pass the correct number of arguments."
        end
      end

      def tool_error_suggestion(details)
        tool = details[:tool_name]
        if tool
          "Tool '#{tool}' is not available. Use a different tool or check the name."
        else
          "The requested tool is not available. List available tools and choose another."
        end
      end

      # Finds similar variable/method names in code using Levenshtein-like matching.
      def find_similar_names(target, code)
        return [] unless code

        # Extract all identifiers from code
        identifiers = code.scan(/\b([a-z_][a-z0-9_]*)\b/i).flatten.uniq
        identifiers.select { |id| similar?(target, id) }.first(3)
      end

      def similar?(a, b)
        return false if a == b
        return true if a.downcase == b.downcase

        # Simple similarity: same prefix or suffix
        a.start_with?(b[0, 3]) || b.start_with?(a[0, 3]) ||
          a.end_with?(b[-3..]) || b.end_with?(a[-3..])
      end

      def calculate_confidence(category, details)
        case category
        when :syntax_error
          details.any? ? 0.9 : 0.7
        when :name_error, :no_method_error
          details[:undefined_name] || details[:undefined_method] ? 0.85 : 0.6
        when :type_error
          details[:from_type] && details[:to_type] ? 0.8 : 0.5
        when :argument_error
          details[:given] && details[:expected] ? 0.9 : 0.6
        when :tool_error
          details[:tool_name] ? 0.95 : 0.7
        when :timeout, :memory_limit, :operation_limit
          0.8
        else
          0.5
        end
      end
    end
  end
end
