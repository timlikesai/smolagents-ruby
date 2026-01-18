module Smolagents
  module Executors
    class Executor
      # Concern for validating execution parameters.
      #
      # Provides validation methods for checking code and language parameters
      # before execution. Includes both raising and non-raising variants.
      #
      # @example Including in an executor
      #   class MyExecutor < Executor
      #     include Validation
      #   end
      module Validation
        # Validates execution parameters and raises on failure.
        #
        # Checks that code is not empty and language is supported.
        #
        # @param code [String] Source code to validate
        # @param language [Symbol] Language to validate
        # @return [void]
        # @raise [ArgumentError] If code is empty or language not supported
        def validate_execution_params!(code, language)
          raise ArgumentError, "Code cannot be empty" if code.to_s.empty?
          raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
        end

        # Validates execution parameters and returns boolean.
        #
        # Non-raising version of validation. Returns true if code is valid
        # and language is supported.
        #
        # @param code [String] Source code to validate
        # @param language [Symbol] Language to validate
        # @return [Boolean] True if valid, false otherwise
        def validate_execution_params(code, language)
          code && !code.to_s.empty? && supports?(language)
        end

        # Alias for validate_execution_params (predicate form).
        # @see #validate_execution_params
        alias valid_execution_params? validate_execution_params
      end
    end
  end
end
