module Smolagents
  module Executors
    # Helpful hints and error message improvements for agent code execution.
    #
    # Provides better error messages that guide models toward correct patterns
    # when they make common mistakes like using string literals instead of
    # interpolation for variable references.
    module Hints
      # Patterns that look like variable references in strings
      VARIABLE_PATTERN = %r{\b([a-z_][a-z0-9_]*)\s*[-+*/]}i

      # Common variable names models use
      COMMON_VAR_NAMES = %w[
        result result1 result2 step1 step2 step3
        value answer output total sum product
        first_result second_result final_result
        initial_result intermediate_result
        a b c x y z n
      ].freeze

      # Analyzes an expression string for likely variable reference mistakes.
      #
      # When a model writes `calculate(expression: "step1 + 10")`, the `step1`
      # inside the string is a literal, not a variable reference. This method
      # detects such patterns and suggests fixes.
      #
      # @param expression [String] The expression that caused an error
      # @param error [Exception] The error that occurred
      # @return [String, nil] A helpful hint, or nil if no hint applies
      #
      # @example
      #   hint = Hints.analyze_expression("step1 + 10", NameError.new("undefined local variable step1"))
      #   # => "It looks like you're trying to use variable 'step1' inside a string..."
      def self.analyze_expression(expression, error)
        return nil unless error.is_a?(NameError)

        # Extract the undefined variable name from the error
        var_name = extract_undefined_var(error)
        return nil unless var_name

        # Check if the variable appears in the expression as a string literal
        return nil unless expression.include?(var_name)

        build_variable_hint(var_name, expression)
      end

      # Builds a helpful hint for variable reference mistakes.
      #
      # @param var_name [String] The undefined variable name
      # @param expression [String] The expression containing the mistake
      # @return [String] A helpful hint message
      def self.build_variable_hint(var_name, expression)
        # Show what they wrote vs what they should write
        expression.gsub(/\b#{Regexp.escape(var_name)}\b/, "\#{#{var_name}}")

        <<~HINT.strip
          Variable '#{var_name}' is referenced as a string literal, not a variable.

          You wrote:    calculate(expression: "#{expression}")
          This passes the literal string "#{expression}" to eval, where '#{var_name}' doesn't exist.

          Fix option 1 - Use string interpolation:
            calculate(expression: "\#{#{var_name}} + 10")

          Fix option 2 - Use direct arithmetic (ToolResult supports math):
            #{var_name} + 10

          The second option is simpler when doing math with tool results.
        HINT
      end

      # Extracts the undefined variable name from a NameError.
      #
      # @param error [NameError] The error to analyze
      # @return [String, nil] The variable name, or nil if not found
      def self.extract_undefined_var(error)
        msg = error.message
        # Ruby 3.x format: "undefined local variable or method `foo'"
        if (match = msg.match(/undefined local variable or method [`'](\w+)[`']/))
          return match[1]
        end

        # Alternative format
        if (match = msg.match(/undefined method [`'](\w+)[`']/)) && COMMON_VAR_NAMES.include?(match[1])
          return match[1]
        end

        nil
      end

      # Wraps a tool's execute block to provide better error messages.
      #
      # @param expression [String] The expression being evaluated
      # @yield The block to execute
      # @return [Object] The result of the block
      # @raise [Smolagents::InterpreterError] With enhanced message on NameError
      def self.with_expression_hints(expression)
        yield
      rescue NameError => e
        hint = analyze_expression(expression, e)
        raise Smolagents::InterpreterError, "#{e.message}\n\nHINT:\n#{hint}" if hint

        raise
      end

      # Creates a calculate tool with helpful error messages.
      #
      # This is a factory method that creates a calculate tool proc with
      # built-in error detection and helpful hints for common mistakes.
      #
      # @return [Proc] A proc that can be used as a calculate tool
      #
      # @example
      #   calculate_tool = Hints.create_helpful_calculate_tool
      #   executor.send_tools("calculate" => calculate_tool)
      def self.create_helpful_calculate_tool
        lambda do |expression:|
          with_expression_hints(expression) do
            # Use a clean binding for eval
            result = eval(expression) # rubocop:disable Security/Eval
            result.is_a?(Numeric) ? result.to_f : result
          end
        end
      end
    end
  end
end
