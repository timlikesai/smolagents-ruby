module Smolagents
  module Utilities
    # Recursive transformation utilities for nested data structures.
    module Transform
      # Primitives that don't need transformation.
      PRIMITIVES = [Integer, Float, Symbol, NilClass, TrueClass, FalseClass].freeze

      module_function

      # Recursively converts all hash keys to symbols.
      #
      # @param obj [Object] Object to transform
      # @return [Object] Object with symbolized keys
      def symbolize_keys(obj)
        case obj
        when Hash then obj.to_h { |key, val| [key.to_sym, symbolize_keys(val)] }
        when Array then obj.map { |item| symbolize_keys(item) }
        else obj
        end
      end

      # Recursively freezes an object and all nested structures.
      #
      # @param obj [Object] Object to freeze
      # @return [Object] Frozen object
      # rubocop:disable Metrics/CyclomaticComplexity -- type dispatch inherently branchy
      def freeze(obj)
        case obj
        when *PRIMITIVES then obj
        when Array then obj.map { |item| freeze(item) }.freeze
        when Hash then obj.transform_values { |val| freeze(val) }.freeze
        when String then obj.frozen? ? obj : obj.dup.freeze
        else safe_freeze(obj)
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Recursively duplicates an object for isolation.
      #
      # @param obj [Object] Object to duplicate
      # @return [Object] Deep copy of the object
      # rubocop:disable Metrics/CyclomaticComplexity -- type dispatch inherently branchy
      def dup(obj)
        case obj
        when *PRIMITIVES then obj
        when String then obj.dup
        when Array then obj.map { |item| dup(item) }
        when Hash then obj.transform_keys { |k| dup(k) }.transform_values { |v| dup(v) }
        else obj.respond_to?(:dup) ? obj.dup : obj
        end
      rescue TypeError, FrozenError
        obj
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Freezes an object safely, handling unfrozen objects.
      def safe_freeze(obj)
        obj.freeze
      rescue FrozenError, TypeError
        obj
      end
    end
  end
end
