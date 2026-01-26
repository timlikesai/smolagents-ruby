module Smolagents
  module Config
    class Configuration
      # Generates validated attribute accessors from DEFAULTS hash.
      #
      # Uses metaprogramming to generate setter methods that:
      # - Check for frozen state before modification
      # - Run the corresponding validator from VALIDATORS
      # - Deep-freeze the value before storage
      #
      # @api private
      module Attributes
        def self.included(base)
          base.attr_reader(*DEFAULTS.keys)
          define_validated_setters(base)
        end

        # Generates setter methods for all configuration attributes.
        #
        # Each setter:
        # 1. Raises FrozenError if configuration is frozen
        # 2. Runs the validator for that attribute (if one exists)
        # 3. Deep-freezes the value
        # 4. Stores it in the instance variable
        #
        # @param base [Class] The class to define setters on
        # @return [void]
        def self.define_validated_setters(base)
          DEFAULTS.each_key do |attr|
            base.define_method(:"#{attr}=") do |value|
              raise FrozenError, "Configuration is frozen" if @frozen

              VALIDATORS[attr]&.call(value)
              instance_variable_set(:"@#{attr}", freeze_value(value))
            end
          end
        end
      end
    end
  end
end
