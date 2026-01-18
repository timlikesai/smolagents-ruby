module Smolagents
  module Security
    # Type checking logic for argument validation.
    module TypeValidator
      TYPE_CHECKS = {
        "string" => ->(v) { v.is_a?(String) },
        "integer" => ->(v) { v.is_a?(Integer) },
        "number" => ->(v) { v.is_a?(Numeric) },
        "boolean" => ->(v) { [true, false].include?(v) },
        "array" => ->(v) { v.is_a?(Array) },
        "hash" => ->(v) { v.is_a?(Hash) }
      }.freeze

      class << self
        def valid_type?(value, type)
          check = TYPE_CHECKS[type]
          check ? check.call(value) : true
        end

        def type_error(type) = "must be a #{type}"

        def check_length(value, max_length, type)
          return nil unless max_length

          case type
          when "string"
            check_string_length(value, max_length)
          when "array"
            check_array_length(value, max_length)
          end
        end

        def check_pattern(value, pattern)
          return nil unless pattern && value.is_a?(String)
          return nil if pattern.match?(value)

          "does not match required pattern"
        end

        private

        def check_string_length(value, max_length)
          return nil if value.length <= max_length

          "exceeds max length of #{max_length}"
        end

        def check_array_length(value, max_length)
          return nil if value.length <= max_length

          "exceeds max items of #{max_length}"
        end
      end
    end
  end
end
