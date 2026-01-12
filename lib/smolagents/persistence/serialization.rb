module Smolagents
  module Persistence
    module Serialization
      PRIMITIVE_TYPES = [NilClass, TrueClass, FalseClass, Numeric, String, Symbol].freeze

      module_function

      def serializable?(value)
        case value
        when *PRIMITIVE_TYPES then true
        when Array then value.all? { |item| serializable?(item) }
        when Hash then value.all? { |key, val| serializable?(key) && serializable?(val) }
        else false
        end
      end

      def deep_symbolize_keys(obj)
        case obj
        when Hash
          obj.to_h { |key, val| [key.to_sym, deep_symbolize_keys(val)] }
        when Array
          obj.map { |item| deep_symbolize_keys(item) }
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
           .reject { |ivar| exclude.include?(ivar_to_key(ivar)) }
           .to_h { |ivar| [ivar_to_key(ivar), obj.instance_variable_get(ivar)] }
           .select { |_, val| serializable?(val) }
      end
    end
  end
end
