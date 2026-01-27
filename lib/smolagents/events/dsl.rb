# Metaprogramming DSL for declarative event class generation.
require_relative "../types/events/event_config"

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
        config = EventConfig.new(predicates:, predicate_field:, freeze_fields: freeze, from_error:, defaults:)
        const_set(name, EventBuilder.build(%i[id sequence] + fields + [:created_at], config))
      end
    end

    # Builds event classes with Data.define.
    module EventBuilder
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- DSL builder requires many method definitions
      def self.build(all_fields, config)
        Data.define(*all_fields) do
          define_singleton_method(:event_config) { config }
          define_singleton_method(:create) { |**kwargs| CreateFactory.call(self, kwargs) }
          define_singleton_method(:event_name) { name.split("::").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase }
          define_singleton_method(:field_names) { members - %i[id sequence created_at] }

          config.predicates.each do |method_name, expected_value|
            define_method(:"#{method_name}?") { send(config.predicate_field) == expected_value }
          end

          define_method(:event_name) { self.class.event_name }
          define_method(:to_json) { |*args| to_h.merge(_type: self.class.name).to_json(*args) }
          define_method(:as_log_entry) { to_h.merge(event_type: event_name, timestamp: created_at.iso8601) }
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end

    # Factory for creating event instances with all transformations applied.
    module CreateFactory
      @sequence_counter = 0
      @sequence_mutex = Mutex.new

      # Get the next sequence number (thread-safe).
      # @return [Integer] Monotonically increasing sequence number
      def self.next_sequence
        @sequence_mutex.synchronize { @sequence_counter += 1 }
      end

      # Reset sequence counter (for testing only).
      # @api private
      def self.reset_sequence!
        @sequence_mutex.synchronize { @sequence_counter = 0 }
      end

      # Current sequence value (for inspection, not guaranteed accurate under concurrency).
      # @return [Integer] Current sequence counter value
      def self.current_sequence
        @sequence_mutex.synchronize { @sequence_counter }
      end

      def self.call(klass, kwargs)
        config = klass.event_config
        ErrorExtractor.call(kwargs) if config.from_error
        DefaultApplier.call(kwargs, config.defaults)
        FieldFreezer.call(kwargs, config.freeze_fields)
        klass.new(id: SecureRandom.uuid, sequence: next_sequence, created_at: Time.now, **kwargs)
      end
    end

    # Extracts error class and message from an :error key.
    module ErrorExtractor
      def self.call(kwargs)
        return unless kwargs[:error]

        err = kwargs.delete(:error)
        kwargs[:error_class] = err.class.name
        kwargs[:error_message] = err.message
      end
    end

    # Applies default values to kwargs for missing keys.
    module DefaultApplier
      def self.call(kwargs, defaults) = defaults.each { |k, v| kwargs[k] = v unless kwargs.key?(k) }
    end

    # Freezes specified fields in kwargs.
    module FieldFreezer
      def self.call(kwargs, fields) = fields.each { |f| kwargs[f] = kwargs[f].freeze if kwargs[f] }
    end
  end
end
