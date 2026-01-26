module Smolagents
  module Types
    module Callbacks
      # Registry methods for callback validation and querying.
      #
      # Provides class-level API for validating events and arguments,
      # retrieving signatures, and listing available events.
      module Registry
        # Checks if an event name is valid.
        #
        # @param event [Symbol] the event name to check
        # @return [Boolean] true if event is registered
        def valid_event?(event) = signatures.key?(event)

        # Validates that an event name is registered.
        #
        # @param event [Symbol] the event name to validate
        # @return [void]
        # @raise [InvalidCallbackError] if event is not registered
        def validate_event!(event)
          return if valid_event?(event)

          valid_events = signatures.keys.map(&:inspect).join(", ")
          raise InvalidCallbackError,
                "Unknown callback event '#{event}'. Valid events: #{valid_events}"
        end

        # Validates callback arguments against a registered event signature.
        #
        # @param event [Symbol] the callback event to validate against
        # @param args [Hash{Symbol => Object}] the arguments to validate
        # @return [void]
        # @raise [InvalidCallbackError] if the event is not registered
        # @raise [InvalidArgumentError] if arguments don't match the signature
        def validate_args!(event, args)
          validate_event!(event)
          signatures[event].validate_args!(event, args)
        end

        # Retrieves the signature for a registered callback event.
        #
        # @param event [Symbol] the callback event name
        # @return [CallbackSignature] the signature for the event
        # @raise [InvalidCallbackError] if the event is not registered
        def signature_for(event)
          validate_event!(event)
          signatures[event]
        end

        # Returns all registered callback event names.
        #
        # @return [Array<Symbol>] list of valid callback event names
        def events = signatures.keys

        private

        def signatures
          @signatures ||= SignatureBuilder.build_all
        end
      end
    end
  end
end
