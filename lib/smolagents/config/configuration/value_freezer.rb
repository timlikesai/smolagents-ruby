module Smolagents
  module Config
    class Configuration
      # Deep-freezes configuration values to prevent accidental mutation.
      #
      # Handles various Ruby types appropriately:
      # - Primitives (nil, Symbol, Integer, Float, true, false) pass through unchanged
      # - Strings are duplicated and frozen unless already frozen
      # - Arrays and Hashes are recursively frozen
      # - Objects like loggers that may not support dup/freeze are returned as-is
      #
      # @api private
      module ValueFreezer
        private

        # Deep-freezes a value for immutable storage.
        #
        # @param value [Object] The value to freeze
        # @return [Object] The frozen value
        def freeze_value(value)
          case value
          when String then freeze_string(value)
          when Array then value.map { |v| freeze_value(v) }.freeze
          when Hash then value.transform_values { |v| freeze_value(v) }.freeze
          else value # Primitives (nil, Symbol, Integer, Float, booleans) and objects like loggers
          end
        end

        def freeze_string(value) = value.frozen? ? value : value.dup.freeze
      end
    end
  end
end
