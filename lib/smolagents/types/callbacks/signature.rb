module Smolagents
  module Types
    module Callbacks
      # Defines expected argument types for a callback event.
      #
      # Encapsulates the contract for a callback: which arguments are required,
      # which are optional, and what types each should have.
      CallbackSignature = Data.define(:required_args, :optional_args, :arg_types) do
        # Validates that callback arguments match the signature.
        #
        # @param event [Symbol] the callback event name (for error messages)
        # @param args [Hash{Symbol => Object}] the arguments to validate
        # @return [void]
        # @raise [InvalidArgumentError] if required args are missing or types don't match
        def validate_args!(event, args)
          validate_required_args!(event, args)
          validate_arg_types!(event, args)
        end

        private

        def validate_required_args!(event, args)
          missing = required_args - args.keys
          return if missing.empty?

          raise InvalidArgumentError,
                "Callback '#{event}' missing required arguments: #{missing.join(", ")}"
        end

        def validate_arg_types!(event, args)
          args.each do |key, value|
            next unless arg_types.key?(key)

            expected_type = TypeResolver.resolve(arg_types[key])
            next if value.nil? || TypeResolver.valid?(value, expected_type)

            raise InvalidArgumentError,
                  "Callback '#{event}' argument '#{key}' expected #{expected_type}, got #{value.class}"
          end
        end
      end
    end
  end
end
