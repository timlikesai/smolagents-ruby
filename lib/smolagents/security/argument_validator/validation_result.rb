module Smolagents
  module Security
    # Immutable result of argument validation.
    #
    # @example Checking validation success
    #   result = ArgumentValidationResult.success(sanitized_value: "hello")
    #   result.valid?  #=> true
    #
    # @example Pattern matching on failure
    #   case result
    #   in { valid: false, errors: }
    #     puts "Errors: #{errors.join(', ')}"
    #   end
    ArgumentValidationResult = Data.define(:valid, :errors, :sanitized_value) do
      class << self
        def success(sanitized_value:)
          new(valid: true, errors: [].freeze, sanitized_value:)
        end

        def failure(errors:)
          errors = Array(errors).freeze
          new(valid: false, errors:, sanitized_value: nil)
        end
      end

      def valid? = valid
      def invalid? = !valid

      def deconstruct_keys(_) = { valid:, errors:, sanitized_value: }
    end
  end
end
