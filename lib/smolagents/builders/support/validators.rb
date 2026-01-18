module Smolagents
  module Builders
    module Support
      # Pre-built validation lambdas for common builder patterns.
      #
      # Use these validators with SetterFactory or ValidatedSetter to validate
      # builder method arguments. Each validator is a callable that returns
      # true for valid values, false otherwise.
      #
      # @example Using with ValidatedSetter
      #   validated_setter :max_steps, validate: Validators::POSITIVE_INTEGER
      #   validated_setter :temperature, validate: Validators.numeric_range(0.0, 2.0)
      module Validators
        # Validates positive integers (> 0).
        POSITIVE_INTEGER = ->(v) { v.is_a?(Integer) && v.positive? }

        # Validates non-negative integers (>= 0).
        NON_NEGATIVE_INTEGER = ->(v) { v.is_a?(Integer) && !v.negative? }

        # Validates non-empty strings.
        NON_EMPTY_STRING = ->(v) { v.is_a?(String) && !v.empty? }

        # Validates boolean values (true or false, not truthy/falsy).
        BOOLEAN = ->(v) { [true, false].include?(v) }

        # Validates symbols.
        SYMBOL = ->(v) { v.is_a?(Symbol) }

        # Validates arrays.
        ARRAY = ->(v) { v.is_a?(Array) }

        # Validates hashes.
        HASH = ->(v) { v.is_a?(Hash) }

        # Validates callables (responds to #call).
        CALLABLE = ->(v) { v.respond_to?(:call) }

        # Validates any numeric value.
        NUMERIC = ->(v) { v.is_a?(Numeric) }

        # Validates positive numeric values.
        POSITIVE_NUMERIC = ->(v) { v.is_a?(Numeric) && v.positive? }

        # Validates a numeric value within a range (inclusive).
        #
        # @param min [Numeric] Minimum value
        # @param max [Numeric] Maximum value
        # @return [Proc] Validator lambda
        def self.numeric_range(min, max)
          ->(v) { v.is_a?(Numeric) && v.between?(min, max) }
        end

        # Validates an integer within a range (inclusive).
        #
        # @param min [Integer] Minimum value
        # @param max [Integer] Maximum value
        # @return [Proc] Validator lambda
        def self.integer_range(min, max)
          ->(v) { v.is_a?(Integer) && v.between?(min, max) }
        end

        # Validates value is one of allowed values.
        #
        # @param allowed [Array] Allowed values
        # @return [Proc] Validator lambda
        def self.one_of(*allowed)
          allowed = allowed.flatten
          ->(v) { allowed.include?(v) }
        end

        # Validates array contains only allowed elements.
        #
        # @param allowed [Array] Allowed element values
        # @return [Proc] Validator lambda
        def self.array_of(*allowed)
          allowed = allowed.flatten
          ->(v) { v.is_a?(Array) && v.all? { |e| allowed.include?(e) } }
        end

        # Validates array elements match a validator.
        #
        # @param element_validator [Proc] Validator for each element
        # @return [Proc] Validator lambda
        def self.array_where(element_validator)
          ->(v) { v.is_a?(Array) && v.all? { |e| element_validator.call(e) } }
        end

        # Combines multiple validators with AND logic.
        #
        # @param validators [Array<Proc>] Validators that must all pass
        # @return [Proc] Combined validator lambda
        def self.all_of(*validators)
          ->(v) { validators.all? { |validator| validator.call(v) } }
        end

        # Combines multiple validators with OR logic.
        #
        # @param validators [Array<Proc>] Validators where at least one must pass
        # @return [Proc] Combined validator lambda
        def self.any_of(*validators)
          ->(v) { validators.any? { |validator| validator.call(v) } }
        end
      end
    end
  end
end
