module Smolagents
  module Tools
    class ToolResult
      # Numeric arithmetic operations for ToolResult.
      #
      # When a ToolResult wraps numeric data, it can participate in arithmetic
      # operations directly. This allows natural code like:
      #
      #   result = calculate(expression: "25 * 4")  # ToolResult(100.0)
      #   answer = result - 50                       # => 50.0
      #
      # Without this, models must use string interpolation workarounds:
      #
      #   result = calculate(expression: "25 * 4")
      #   answer = calculate(expression: "#{result} - 50")  # Awkward!
      #
      # == Supported Operations
      #
      # Arithmetic: +, -, *, /, %, **
      # Comparison: <, <=, >, >=, <=> (via Comparable)
      # Coercion: Allows `50 + result` as well as `result + 50`
      #
      # == Type Safety
      #
      # Operations only work when the underlying data is Numeric.
      # TypeError is raised for non-numeric data with a clear message.
      #
      # @example Direct arithmetic
      #   result = ToolResult.new(100.0, tool_name: "calc")
      #   result - 50      # => 50.0
      #   result * 2       # => 200.0
      #   50 + result      # => 150.0 (via coerce)
      #
      # @example In agent code
      #   step1 = calculate(expression: "25 * 4")
      #   final = step1 - 50
      #   final_answer(answer: final)
      #
      # @example Type error on non-numeric
      #   result = ToolResult.new("hello", tool_name: "test")
      #   result + 5  # => TypeError: Cannot perform arithmetic on String
      module Arithmetic
        # Enables reverse operations like `50 + result`.
        #
        # Ruby calls coerce when the left operand doesn't know how to handle
        # the right operand. We return [other, data] so Ruby can retry with
        # the unwrapped numeric value.
        #
        # @param other [Numeric] The left-hand operand
        # @return [Array<Numeric, Numeric>] Pair for Ruby's coercion protocol
        # @raise [TypeError] If data is not Numeric
        def coerce(other)
          ensure_numeric!(:coerce)
          [other, @data]
        end

        # Addition. Returns raw numeric result, not wrapped ToolResult.
        #
        # When both operands have numeric data, performs arithmetic addition.
        # When either has non-numeric data, falls back to Creation#+ for array concat.
        #
        # @param other [Numeric, ToolResult] Value to add
        # @return [Numeric] Sum of data and other (when numeric)
        # @return [ToolResult] Concatenated result (when non-numeric ToolResults)
        # @raise [TypeError] If data is not Numeric and other is not ToolResult
        def +(other)
          # If both are ToolResult, check if both are numeric for arithmetic
          if other.is_a?(ToolResult)
            # Both numeric: do arithmetic
            return numeric_operation(:+, other) if @data.is_a?(Numeric) && other.data.is_a?(Numeric)

            # Otherwise fall back to array concatenation (Creation#+)
            return super
          end

          # ToolResult + scalar: must be numeric
          numeric_operation(:+, other)
        end

        # Subtraction.
        # @param other [Numeric] Value to subtract
        # @return [Numeric] Difference
        # @raise [TypeError] If data is not Numeric
        def -(other)
          numeric_operation(:-, other)
        end

        # Multiplication.
        # @param other [Numeric] Value to multiply by
        # @return [Numeric] Product
        # @raise [TypeError] If data is not Numeric
        def *(other)
          numeric_operation(:*, other)
        end

        # Division.
        # @param other [Numeric] Value to divide by
        # @return [Numeric] Quotient
        # @raise [TypeError] If data is not Numeric
        # @raise [ZeroDivisionError] If other is zero
        def /(other)
          numeric_operation(:/, other)
        end

        # Modulo.
        # @param other [Numeric] Divisor
        # @return [Numeric] Remainder
        # @raise [TypeError] If data is not Numeric
        def %(other)
          numeric_operation(:%, other)
        end

        # Exponentiation.
        # @param other [Numeric] Exponent
        # @return [Numeric] Result of raising data to power
        # @raise [TypeError] If data is not Numeric
        def **(other)
          numeric_operation(:**, other)
        end

        # Negation (unary minus).
        # @return [Numeric] Negated value
        # @raise [TypeError] If data is not Numeric
        def -@
          ensure_numeric!(:-@)
          -@data
        end

        # Unary plus (returns data unchanged).
        # @return [Numeric] The numeric value
        # @raise [TypeError] If data is not Numeric
        def +@
          ensure_numeric!(:+@)
          +@data
        end

        # Absolute value.
        # @return [Numeric] Absolute value of data
        # @raise [TypeError] If data is not Numeric
        def abs
          ensure_numeric!(:abs)
          @data.abs
        end

        # Comparison for Comparable.
        # Only compares when both are numeric or both are ToolResult with numeric data.
        #
        # @param other [Numeric, ToolResult] Value to compare against
        # @return [Integer, nil] -1, 0, 1, or nil if not comparable
        def <=>(other)
          return nil unless @data.is_a?(Numeric)

          other_val = other.is_a?(ToolResult) ? other.data : other
          return nil unless other_val.is_a?(Numeric)

          @data <=> other_val
        end

        # Converts to Integer.
        # @return [Integer] Integer representation
        # @raise [TypeError] If data is not Numeric
        def to_int
          ensure_numeric!(:to_int)
          @data.to_int
        end

        # Converts to Float.
        # @return [Float] Float representation
        # @raise [TypeError] If data cannot be converted to float
        def to_f
          return @data.to_f if @data.respond_to?(:to_f)

          raise TypeError, "Cannot convert #{@data.class} to Float"
        end

        # Checks if the underlying data is numeric.
        # @return [Boolean] True if data is Numeric
        def numeric?
          @data.is_a?(Numeric)
        end

        # Returns the numeric value if present, nil otherwise.
        # Useful for safe extraction without exceptions.
        # @return [Numeric, nil] The numeric value or nil
        def to_numeric
          numeric? ? @data : nil
        end

        # Rounds to the specified number of decimal places.
        # @param digits [Integer] Number of decimal places (default: 0)
        # @return [Numeric] Rounded value
        # @raise [TypeError] If data is not Numeric
        def round(digits = 0)
          ensure_numeric!(:round)
          @data.round(digits)
        end

        # Rounds up to the nearest integer.
        # @return [Integer] Ceiling value
        # @raise [TypeError] If data is not Numeric
        def ceil
          ensure_numeric!(:ceil)
          @data.ceil
        end

        # Rounds down to the nearest integer.
        # @return [Integer] Floor value
        # @raise [TypeError] If data is not Numeric
        def floor
          ensure_numeric!(:floor)
          @data.floor
        end

        private

        # Performs a numeric operation, unwrapping ToolResult operands.
        #
        # @param operator [Symbol] The operation (:+, :-, :*, :/, :%, :**)
        # @param other [Numeric, ToolResult] The other operand
        # @return [Numeric] The result of the operation
        # @raise [TypeError] If data is not Numeric
        def numeric_operation(operator, other)
          ensure_numeric!(operator)
          other_val = other.is_a?(ToolResult) ? other.data : other
          @data.send(operator, other_val)
        end

        # Raises TypeError if data is not Numeric.
        #
        # @param operation [Symbol] The attempted operation (for error message)
        # @raise [TypeError] If data is not Numeric
        def ensure_numeric!(operation)
          return if @data.is_a?(Numeric)

          raise TypeError,
                "Cannot perform #{operation} on ToolResult containing #{@data.class}. " \
                "Arithmetic operations require numeric data."
        end
      end
    end
  end
end
