module Smolagents
  module Config
    class Configuration
      # Provides validation methods for configuration.
      #
      # Runs all validators from VALIDATORS hash against current values
      # and reports validity status.
      #
      # @api private
      module Validation
        # Validates all configuration values.
        #
        # @return [true] if valid
        # @raise [ArgumentError] if any value is invalid
        def validate! # rubocop:disable Naming/PredicateMethod
          VALIDATORS.each do |key, validator|
            validator.call(instance_variable_get(:"@#{key}"))
          end
          true
        end

        # Checks if configuration is valid without raising.
        #
        # @return [Boolean] true if valid, false otherwise
        def validate
          validate!
          true
        rescue ArgumentError => e
          warn "[Configuration#validate] validation failed: #{e.message}" if $DEBUG
          false
        end
        alias valid? validate
      end
    end
  end
end
