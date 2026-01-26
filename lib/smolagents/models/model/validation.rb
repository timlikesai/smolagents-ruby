module Smolagents
  module Models
    class Model
      # Parameter validation for Model instances.
      #
      # Provides helpers for validating required initialization parameters.
      module Validation
        # Validates that all required parameters are present.
        #
        # @param required [Array<Symbol>] Required parameter names to check
        # @param kwargs [Hash] The provided parameters hash to validate
        #
        # @return [void]
        # @raise [ArgumentError] When any required parameters are missing
        def validate_required_params(required, kwargs)
          missing = required - kwargs.keys
          raise ArgumentError, "Missing required parameters: #{missing.join(", ")}" unless missing.empty?
        end
      end
    end
  end
end
