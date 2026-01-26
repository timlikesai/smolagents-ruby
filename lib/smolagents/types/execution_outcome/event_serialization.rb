module Smolagents
  module Types
    module OutcomeComponents
      # Event payload serialization for instrumentation.
      #
      # Provides standardized format for events emitted by the telemetry system.
      # Include this in outcome types to enable consistent event emission.
      module EventSerialization
        # Converts outcome to event payload for instrumentation.
        #
        # @return [Hash] Event payload with :outcome, :duration, :timestamp, :metadata,
        #                 and conditionally :value, :error, :error_message
        def to_event_payload
          base_payload.merge(conditional_payload).compact
        end

        private

        def base_payload
          {
            outcome: state,
            duration:,
            timestamp: Time.now.utc.iso8601,
            metadata:
          }
        end

        def conditional_payload
          return { value: } if completed?
          return { error: error.class.name, error_message: error.message } if error?

          {}
        end
      end
    end
  end
end
