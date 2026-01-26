module Smolagents
  module Types
    module Callbacks
      # Resolves and validates type specifications for callback arguments.
      #
      # Handles string type names (resolved via const_get), arrays of types,
      # and direct class references.
      module TypeResolver
        module_function

        # Resolves a type specification to actual type(s).
        #
        # @param type_spec [Class, String, Array] the type specification
        # @return [Class, Array<Class>] resolved type(s)
        def resolve(type_spec)
          case type_spec
          when String then Smolagents.const_get(type_spec)
          when Array then type_spec.map { |spec| resolve(spec) }
          else type_spec
          end
        end

        # Checks if a value matches an expected type.
        #
        # @param value [Object] the value to check
        # @param expected_type [Class, Array<Class>] expected type(s)
        # @return [Boolean] true if value matches
        def valid?(value, expected_type)
          case expected_type
          when Array then expected_type.any? { |type| value.is_a?(type) }
          when Class then value.is_a?(expected_type)
          else false
          end
        end
      end
    end
  end
end
