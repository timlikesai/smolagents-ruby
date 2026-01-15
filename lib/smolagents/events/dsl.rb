# Metaprogramming DSL for declarative event class generation.
module Smolagents
  module Events
    # DSL for generating immutable event types with Data.define.
    #
    # @example Basic event
    #   define_event :ToolCallRequested, fields: %i[tool_name args], freeze: [:args]
    #
    # @example Event with predicates (default field is :outcome)
    #   define_event :StepCompleted, fields: %i[step_number outcome observations],
    #     predicates: { success: :success, error: :error, final_answer: :final_answer }
    #
    # @example Event with predicates on custom field
    #   define_event :ControlYielded, fields: %i[request_type request_id prompt],
    #     predicates: { user_input: :user_input, confirmation: :confirmation },
    #     predicate_field: :request_type
    #
    # @example Event with error extraction
    #   define_event :ErrorOccurred, fields: %i[context recoverable],
    #     from_error: true, defaults: { context: {}, recoverable: false }
    module DSL
      def define_event(name, fields:, predicates: {}, predicate_field: :outcome, freeze: [], from_error: false,
                       defaults: {})
        all_fields = [:id] + fields + [:created_at]

        event_class = Data.define(*all_fields) do
          define_singleton_method(:create) do |**kwargs|
            # Handle error extraction
            if from_error && kwargs[:error]
              err = kwargs.delete(:error)
              kwargs[:error_class] = err.class.name
              kwargs[:error_message] = err.message
            end

            # Apply defaults
            defaults.each { |k, v| kwargs[k] = v unless kwargs.key?(k) }

            # Freeze specified fields
            freeze.each { |f| kwargs[f] = kwargs[f].freeze if kwargs[f] }

            new(id: SecureRandom.uuid, created_at: Time.now, **kwargs)
          end

          # Generate predicate methods
          predicates.each do |method_name, expected_value|
            define_method(:"#{method_name}?") { send(predicate_field) == expected_value }
          end
        end

        const_set(name, event_class)
      end
    end
  end
end
