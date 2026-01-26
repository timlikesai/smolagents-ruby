module Smolagents
  module Executors
    # Ractor boundary serialization for safe data passing.
    #
    # Converts objects to shareable form (frozen or serialized) for crossing
    # Ractor boundaries. Objects must be shareable to pass between Ractors.
    #
    # == Shareability Rules
    #
    # - Primitives (Integer, Float, Symbol, nil, true, false) - always shareable
    # - Frozen strings - shareable by reference
    # - Frozen arrays/hashes - shareable if contents are shareable
    # - Data.define instances - shareable when all fields are shareable
    # - Procs/Lambdas - NEVER shareable, converted to strings
    #
    # == Fallback Behavior
    #
    # When standard preparation fails (e.g., objects with singleton classes,
    # complex nesting, or circular references), Ractor.make_shareable is
    # attempted. This freezes the object deeply but ensures shareability.
    #
    # @api private
    module RactorSerialization
      # Maximum recursion depth for circular reference protection
      MAX_DEPTH = 100

      private

      # Prepares an object for passing across Ractor boundaries.
      #
      # @param obj [Object] Object to prepare
      # @param depth [Integer] Current recursion depth (for circular reference protection)
      # @return [Object] Ractor-shareable version of the object
      def prepare_for_ractor(obj, depth: 0)
        return obj if primitive?(obj) || ::Ractor.shareable?(obj)

        if depth > MAX_DEPTH
          # Circular reference or extremely deep nesting - fall back to string
          return obj.to_s.freeze
        end

        prepare_with_fallback(obj, depth)
      end

      def primitive?(obj)
        obj.nil? || obj == true || obj == false || obj.is_a?(Integer) || obj.is_a?(Float) || obj.is_a?(Symbol)
      end

      # Attempts standard preparation, falls back to make_shareable if needed.
      def prepare_with_fallback(obj, depth)
        prepare_complex(obj, depth)
      rescue ::Ractor::IsolationError, FrozenError => e
        # Object couldn't be prepared normally - try make_shareable
        try_make_shareable(obj, e)
      end

      # Attempts to make object shareable using Ractor.make_shareable.
      # Falls back to string representation if that also fails.
      def try_make_shareable(obj, _original_error)
        # Clone to avoid mutating original, then make shareable
        cloned = deep_dup(obj)
        ::Ractor.make_shareable(cloned)
      rescue ::Ractor::IsolationError, TypeError, ArgumentError
        # Object cannot be made shareable (e.g., contains Procs, IO, etc.)
        obj.to_s.freeze
      end

      # Deep duplicates an object for make_shareable.
      def deep_dup(obj) = Utilities::Transform.dup(obj)

      def prepare_complex(obj, depth)
        case obj
        when String then obj.frozen? ? obj : obj.dup.freeze
        when Array then prepare_array(obj, depth)
        when Hash then prepare_hash(obj, depth)
        else safe_serialize(obj, depth)
        end
      end

      def prepare_array(obj, depth)
        obj.map { |item| prepare_for_ractor(item, depth: depth + 1) }.freeze
      end

      def prepare_hash(obj, depth)
        obj.transform_keys { |k| prepare_for_ractor(k, depth: depth + 1) }
           .transform_values { |v| prepare_for_ractor(v, depth: depth + 1) }
           .freeze
      end

      def safe_serialize(obj, depth)
        case obj
        when Proc then obj.to_s.freeze
        when Range, Set then prepare_for_ractor(obj.to_a, depth: depth + 1)
        when Struct, Data then prepare_for_ractor(obj.to_h, depth: depth + 1)
        when Exception then prepare_exception(obj, depth)
        else serialize_fallback(obj, depth)
        end
      end

      # Prepares an exception for Ractor boundary crossing.
      def prepare_exception(obj, depth)
        {
          class: obj.class.name.freeze,
          message: prepare_for_ractor(obj.message, depth: depth + 1),
          backtrace: prepare_for_ractor(obj.backtrace || [], depth: depth + 1)
        }.freeze
      end

      def serialize_fallback(obj, depth)
        # Check for singleton class (indicates object has singleton methods)
        return try_make_shareable(obj, nil) if singleton_methods?(obj)

        try_conversion(obj, depth)
      end

      # Attempts to convert object via to_h or to_a, with exception handling.
      def try_conversion(obj, depth)
        try_hash_conversion(obj, depth) || try_array_conversion(obj, depth) || obj.to_s.freeze
      rescue StandardError
        obj.to_s.freeze
      end

      def try_hash_conversion(obj, depth)
        return nil if !obj.respond_to?(:to_h) || obj.is_a?(Array)

        hash = obj.to_h
        prepare_for_ractor(hash, depth: depth + 1) if hash.is_a?(Hash)
      end

      def try_array_conversion(obj, depth)
        return nil unless obj.respond_to?(:to_a)

        array = obj.to_a
        prepare_for_ractor(array, depth: depth + 1) if array.is_a?(Array)
      end

      # Checks if object has singleton methods that would prevent sharing.
      def singleton_methods?(obj)
        obj.singleton_methods.any?
      rescue TypeError
        # Some objects don't support singleton_methods
        false
      end
    end
  end
end
