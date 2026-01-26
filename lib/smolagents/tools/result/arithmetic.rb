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
      # @see Creation For array concatenation with +
      module Arithmetic
        # Binary operators that delegate to numeric_operation.
        # Generated dynamically to avoid repetition.
        %i[- * / % **].each do |op|
          define_method(op) { |other| numeric_operation(op, other) }
        end

        # Delegation methods that call the same method on @data.
        # Generated dynamically to avoid repetition.
        %i[abs ceil floor].each do |method|
          define_method(method) do
            ensure_numeric!(method)
            @data.send(method)
          end
        end

        # Enables reverse operations like `50 + result`.
        # @param other [Numeric] The left-hand operand
        # @return [Array<Numeric, Numeric>] Pair for Ruby's coercion protocol
        def coerce(other)
          ensure_numeric!(:coerce)
          [other, @data]
        end

        # Addition with special handling for ToolResult concatenation.
        # @param other [Numeric, ToolResult] Value to add
        # @return [Numeric, ToolResult] Sum or concatenated result
        def +(other)
          if other.is_a?(ToolResult)
            return numeric_operation(:+, other) if @data.is_a?(Numeric) && other.data.is_a?(Numeric)

            return super # Fall back to Creation#+ for concatenation
          end
          numeric_operation(:+, other)
        end

        # Negation (unary minus).
        # @return [Numeric] Negated value
        def -@
          ensure_numeric!(:-@)
          -@data
        end

        # Unary plus (returns data unchanged).
        # @return [Numeric] The numeric value
        def +@
          ensure_numeric!(:+@)
          +@data
        end

        # Comparison for Comparable.
        # @param other [Numeric, ToolResult] Value to compare
        # @return [Integer, nil] -1, 0, 1, or nil if not comparable
        def <=>(other)
          return nil unless @data.is_a?(Numeric)

          other_val = other.is_a?(ToolResult) ? other.data : other
          return nil unless other_val.is_a?(Numeric)

          @data <=> other_val
        end

        # Converts to Integer.
        # @return [Integer] Integer representation
        def to_int
          ensure_numeric!(:to_int)
          @data.to_int
        end

        # Converts to Float.
        # @return [Float] Float representation
        def to_f
          return @data.to_f if @data.respond_to?(:to_f)

          raise TypeError, "Cannot convert #{@data.class} to Float"
        end

        # Checks if the underlying data is numeric.
        # @return [Boolean] True if data is Numeric
        def numeric? = @data.is_a?(Numeric)

        # Returns the numeric value if present, nil otherwise.
        # @return [Numeric, nil] The numeric value or nil
        def to_numeric = numeric? ? @data : nil

        # Rounds to the specified number of decimal places.
        # @param digits [Integer] Number of decimal places (default: 0)
        # @return [Numeric] Rounded value
        def round(digits = 0)
          ensure_numeric!(:round)
          @data.round(digits)
        end

        private

        # Performs a numeric operation, unwrapping ToolResult operands.
        # @param operator [Symbol] The operation (:+, :-, :*, :/, :%, :**)
        # @param other [Numeric, ToolResult] The other operand
        # @return [Numeric] The result of the operation
        def numeric_operation(operator, other)
          ensure_numeric!(operator)
          other_val = other.is_a?(ToolResult) ? other.data : other
          @data.send(operator, other_val)
        end

        # Raises TypeError if data is not Numeric.
        # @param operation [Symbol] The attempted operation (for error message)
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
