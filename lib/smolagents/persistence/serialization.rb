module Smolagents
  module Persistence
    # Utility methods for serializing Ruby objects to JSON-safe structures.
    #
    # Serialization provides helper methods used by manifests to convert
    # Ruby objects into JSON-serializable hashes and back.
    #
    # @api private
    module Serialization
      # @return [Array<Class>] Types that are directly JSON-serializable
      PRIMITIVE_TYPES = [NilClass, TrueClass, FalseClass, Numeric, String, Symbol].freeze

      module_function

      # Checks if a value can be serialized to JSON.
      #
      # @param value [Object] Value to check
      # @return [Boolean] True if value is serializable
      def serializable?(value)
        case value
        when *PRIMITIVE_TYPES then true
        when Array then value.all? { |item| serializable?(item) }
        when Hash then value.all? { |key, val| serializable?(key) && serializable?(val) }
        else false
        end
      end

      # Recursively converts all hash keys to symbols.
      #
      # @param obj [Object] Object to transform
      # @return [Object] Transformed object with symbolized keys
      def deep_symbolize_keys(obj) = Utilities::Transform.symbolize_keys(obj)

      # Converts top-level hash keys to symbols.
      #
      # @param hash [Hash] Hash to transform
      # @return [Hash] Hash with symbolized keys
      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end

      # Converts an instance variable name to a config key.
      #
      # @param ivar [Symbol] Instance variable like :@foo
      # @return [Symbol] Config key like :foo
      def ivar_to_key(ivar)
        ivar.to_s.delete_prefix("@").to_sym
      end

      # Extracts serializable instance variables from an object.
      #
      # @param obj [Object] Object to extract from
      # @param exclude [Array<Symbol>] Variable names to skip
      # @return [Hash] Serializable configuration hash
      def extract_ivars(obj, exclude: [])
        obj.instance_variables
           .reject { |ivar| exclude.include?(ivar_to_key(ivar)) }
           .to_h { |ivar| [ivar_to_key(ivar), obj.instance_variable_get(ivar)] }
           .select { |_, val| serializable?(val) }
      end
    end
  end
end
