module Smolagents
  module Callbacks
    class InvalidCallbackError < ArgumentError; end
    class InvalidArgumentError < ArgumentError; end

    CallbackSignature = Data.define(:required_args, :optional_args, :arg_types) do
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

    SIGNATURES = {
      step_start: CallbackSignature.new(
        required_args: [:step_number],
        optional_args: [],
        arg_types: { step_number: Integer }
      ),
      step_complete: CallbackSignature.new(
        required_args: [:step],
        optional_args: [:monitor],
        arg_types: { step: "ActionStep", monitor: ["Concerns::Monitorable::StepMonitor", NilClass] }
      ),
      task_complete: CallbackSignature.new(
        required_args: [:result],
        optional_args: [],
        arg_types: { result: "RunResult" }
      ),
      max_steps_reached: CallbackSignature.new(
        required_args: [:step_count],
        optional_args: [],
        arg_types: { step_count: Integer }
      ),
      on_step_complete: CallbackSignature.new(
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
        arg_types: { usage: "TokenUsage" }
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

      def validate_args!(event, args)
        validate_event!(event)
        SIGNATURES[event].validate_args!(event, args)
      end

      def signature_for(event)
        validate_event!(event)
        SIGNATURES[event]
      end

      def events = SIGNATURES.keys
    end
  end
end
