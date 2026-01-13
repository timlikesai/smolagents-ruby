module Smolagents
  module Types
    # Callback validation and type definitions.
    #
    # The Callbacks module provides type-safe callback registration and
    # validation for agent events. Each event has a defined signature
    # specifying required and optional arguments with type constraints.
    #
    # @example Validating callback arguments
    #   Types::Callbacks.validate_args!(:after_step, { step: action_step, monitor: mon })
    #
    # @example Checking valid events
    #   Types::Callbacks.valid_event?(:before_step)  # => true
    #   Types::Callbacks.events  # => [:before_step, :after_step, ...]
    module Callbacks
      # Raised when an invalid callback event is registered or validated.
      #
      # @example
      #   Types::Callbacks.validate_event!(:invalid_event)  # => InvalidCallbackError
      class InvalidCallbackError < ArgumentError; end

      # Raised when callback arguments fail validation.
      #
      # Triggered when required arguments are missing, have wrong types, or fail type constraints.
      #
      # @example
      #   Types::Callbacks.validate_args!(:after_step, {})  # => InvalidArgumentError (missing :step)
      class InvalidArgumentError < ArgumentError; end

      # Defines expected argument types for a callback event.
      #
      # Encapsulates the contract for a callback: which arguments are required,
      # which are optional, and what types each should have.
      CallbackSignature = Data.define(:required_args, :optional_args, :arg_types) do
        # Validates that callback arguments match the signature.
        #
        # Checks that all required arguments are present and that all provided
        # arguments match their declared types. Raises InvalidArgumentError if
        # validation fails.
        #
        # @param event [Symbol] the callback event name (for error messages)
        # @param args [Hash{Symbol => Object}] the arguments to validate
        #
        # @return [void]
        #
        # @raise [InvalidArgumentError] if required args are missing or types don't match
        #
        # @example Valid arguments
        #   sig = Types::Callbacks.signature_for(:after_step)
        #   sig.validate_args!(:after_step, { step: action_step })  # => nil
        #
        # @example Missing required argument
        #   sig.validate_args!(:after_step, {})  # => InvalidArgumentError
        #
        # @example Invalid type
        #   sig.validate_args!(:after_step, { step: "not a step" })  # => InvalidArgumentError
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

            expected_type = resolve_type(arg_types[key])
            next if value.nil? || validate_type(value, expected_type)

            raise InvalidArgumentError,
                  "Callback '#{event}' argument '#{key}' expected #{expected_type}, got #{value.class}"
          end
        end

        def resolve_type(type_spec)
          case type_spec
          when String then Smolagents.const_get(type_spec)
          when Array then type_spec.map { |spec| resolve_type(spec) }
          else type_spec
          end
        end

        def validate_type(value, expected_type)
          case expected_type
          when Array then expected_type.any? { |type| value.is_a?(type) }
          when Class then value.is_a?(expected_type)
          else false
          end
        end
      end

      # Standardized callback naming convention:
      # - before_X: triggered before an action
      # - after_X: triggered after an action completes
      # - on_X: triggered when something happens (events/errors)
      SIGNATURES = {
        before_step: CallbackSignature.new(
          required_args: [:step_number],
          optional_args: [],
          arg_types: { step_number: Integer }
        ),
        after_step: CallbackSignature.new(
          required_args: [:step],
          optional_args: [:monitor],
          arg_types: { step: "Types::ActionStep", monitor: ["Concerns::Monitorable::StepMonitor", NilClass] }
        ),
        after_task: CallbackSignature.new(
          required_args: [:result],
          optional_args: [],
          arg_types: { result: "Types::RunResult" }
        ),
        on_max_steps: CallbackSignature.new(
          required_args: [:step_count],
          optional_args: [],
          arg_types: { step_count: Integer }
        ),
        after_monitor: CallbackSignature.new(
          required_args: %i[step_name monitor],
          optional_args: [],
          arg_types: { step_name: [Symbol, String], monitor: "Concerns::Monitorable::StepMonitor" }
        ),
        on_step_error: CallbackSignature.new(
          required_args: %i[step_name error monitor],
          optional_args: [],
          arg_types: {
            step_name: [Symbol, String],
            error: StandardError,
            monitor: "Concerns::Monitorable::StepMonitor"
          }
        ),
        on_tokens_tracked: CallbackSignature.new(
          required_args: [:usage],
          optional_args: [],
          arg_types: { usage: "Types::TokenUsage" }
        )
      }.freeze

      class << self
        def valid_event?(event) = SIGNATURES.key?(event)

        def validate_event!(event)
          return if valid_event?(event)

          valid_events = SIGNATURES.keys.map(&:inspect).join(", ")
          raise InvalidCallbackError,
                "Unknown callback event '#{event}'. Valid events: #{valid_events}"
        end

        # Validates callback arguments against a registered event signature.
        #
        # Ensures the event is valid and that all provided arguments match the
        # event's signature (required args present, types correct).
        #
        # @param event [Symbol] the callback event to validate against
        # @param args [Hash{Symbol => Object}] the arguments to validate
        #
        # @return [void]
        #
        # @raise [InvalidCallbackError] if the event is not registered
        # @raise [InvalidArgumentError] if arguments don't match the signature
        #
        # @example Validating before_step callback
        #   Types::Callbacks.validate_args!(:before_step, { step_number: 1 })
        #
        # @example Validating after_step with optional monitor
        #   Types::Callbacks.validate_args!(:after_step, { step: action_step, monitor: nil })
        def validate_args!(event, args)
          validate_event!(event)
          SIGNATURES[event].validate_args!(event, args)
        end

        # Retrieves the signature for a registered callback event.
        #
        # @param event [Symbol] the callback event name
        #
        # @return [CallbackSignature] the signature defining event's required/optional args and types
        #
        # @raise [InvalidCallbackError] if the event is not registered
        #
        # @example Getting signature for after_step
        #   sig = Types::Callbacks.signature_for(:after_step)
        #   sig.required_args  # => [:step]
        #   sig.optional_args  # => [:monitor]
        def signature_for(event)
          validate_event!(event)
          SIGNATURES[event]
        end

        # Returns all registered callback event names.
        #
        # @return [Array<Symbol>] list of valid callback event names
        #
        # @example
        #   Types::Callbacks.events
        #   # => [:before_step, :after_step, :after_task, :on_max_steps, ...]
        def events = SIGNATURES.keys
      end
    end
  end
end
