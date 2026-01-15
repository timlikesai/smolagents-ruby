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
    # @api private
    module RactorSerialization
      private

      def prepare_for_ractor(obj)
        return obj if primitive?(obj) || ::Ractor.shareable?(obj)

        prepare_complex(obj)
      end

      def primitive?(obj)
        obj.nil? || obj == true || obj == false || obj.is_a?(Integer) || obj.is_a?(Float) || obj.is_a?(Symbol)
      end

      def prepare_complex(obj)
        case obj
        when String then obj.frozen? ? obj : obj.dup.freeze
        when Array then obj.map { |item| prepare_for_ractor(item) }.freeze
        when Hash then prepare_hash(obj)
        else safe_serialize(obj)
        end
      end

      def prepare_hash(obj)
        obj.transform_keys { |k| prepare_for_ractor(k) }
           .transform_values { |v| prepare_for_ractor(v) }
           .freeze
      end

      def safe_serialize(obj)
        case obj
        when Range, Set then prepare_for_ractor(obj.to_a)
        when Struct, Data then prepare_for_ractor(obj.to_h)
        else serialize_fallback(obj)
        end
      end

      def serialize_fallback(obj)
        if obj.respond_to?(:to_h) && !obj.is_a?(Array) then prepare_for_ractor(obj.to_h)
        elsif obj.respond_to?(:to_a) then prepare_for_ractor(obj.to_a)
        else obj.to_s.freeze
        end
      end
    end
  end
end
