module Smolagents
  module Persistence
    module Serialization
      PRIMITIVE_TYPES = [NilClass, TrueClass, FalseClass, Numeric, String, Symbol].freeze

      module_function

      def serializable?(value)
        case value
        when *PRIMITIVE_TYPES then true
        when Array then value.all? { |v| serializable?(v) }
        when Hash then value.all? { |k, v| serializable?(k) && serializable?(v) }
        else false
        end
      end

      def deep_symbolize_keys(obj)
        case obj
        when Hash
          obj.to_h { |k, v| [k.to_sym, deep_symbolize_keys(v)] }
        when Array
          obj.map { |v| deep_symbolize_keys(v) }
        else
          obj
        end
      end

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end

      def ivar_to_key(ivar)
        ivar.to_s.delete_prefix("@").to_sym
      end

      def extract_ivars(obj, exclude: [])
        obj.instance_variables
           .reject { |v| exclude.include?(ivar_to_key(v)) }
           .to_h { |v| [ivar_to_key(v), obj.instance_variable_get(v)] }
           .select { |_, v| serializable?(v) }
      end
    end
  end
end
