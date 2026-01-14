module Smolagents
  module Telemetry
    # Data-focused instrumentation for event collection.
    #
    # Instrumentation is PURELY for data collection - it observes operations
    # and emits structured events. It does NOT control flow or determine outcomes.
    #
    # Key principles:
    # 1. Instrumentation collects data, does not control
    # 2. Operations produce ExecutionOutcome objects
    # 3. Events signal state changes with structured data
    # 4. Subscribers react to events (logging, metrics, tracing)
    # 5. No sleep/polling - use Thread::Queue for async coordination
    #
    # @example Data collection
    #   Instrumentation.subscriber = ->(event, payload) {
    #     metrics << { event: event, outcome: payload[:outcome], duration: payload[:duration] }
    #   }
    #
    # @example Observing an operation that returns ExecutionOutcome
    #   outcome = Instrumentation.observe("smolagents.tool.call", tool_name: "search") do
    #     tool.execute_with_outcome(query: "Ruby 4.0")
    #   end
    #
    #   # Instrumentation emits event with outcome data
    #   # Returns outcome for pattern matching
    #   case outcome
    #   in ExecutionOutcome[state: :success, value:]
    #     # continue
    #   end
    #
    # @example Legacy code (backward compatibility)
    #   # For code that still raises exceptions
    #   Instrumentation.instrument("legacy.operation") do
    #     old_code()  # May raise
    #   end
    #
    module Instrumentation
      class << self
        # @return [Proc, nil] The subscriber that receives instrumentation events
        attr_accessor :subscriber

        # Observes an operation that returns ExecutionOutcome.
        #
        # This is the PRIMARY instrumentation method for outcome-based operations.
        # It observes the outcome and emits an event with structured data.
        # NO control flow happens here - purely data collection.
        #
        # @param event [String, Symbol] Event name (e.g., "smolagents.tool.call")
        # @param payload [Hash] Additional context for the event
        # @yield Block that returns an ExecutionOutcome
        # @return [ExecutionOutcome] The outcome from the block (unchanged)
        def observe(event, payload = {})
          return yield unless subscriber

          outcome = yield

          # Emit event with outcome data - pure observation
          subscriber.call(event, payload.merge(outcome.to_event_payload))

          outcome # Return unchanged for caller to handle
        end

        # Instruments a block for legacy code (backward compatibility).
        #
        # This method wraps exception-based operations and emits events.
        # Distinguishes FinalAnswerException (completion) from errors.
        #
        # Prefer #observe for new code that returns ExecutionOutcome.
        #
        # @param event [String, Symbol] Event name
        # @param payload [Hash] Additional context
        # @yield The block to instrument
        # @return [Object] The block's return value
        # @raise [StandardError] Re-raises any exception after emitting event
        def instrument(event, payload = {})
          return yield unless subscriber

          start_time = monotonic_now
          result = yield
          emit(event, payload, :success, duration_since(start_time))
          result
        rescue Smolagents::FinalAnswerException => e
          emit(event, payload, :final_answer, duration_since(start_time), value: e.value)
          raise
        rescue StandardError => e
          emit(event, payload, :error, duration_since(start_time), error: e.class.name, error_message: e.message)
          raise
        end

        private

        def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        def duration_since(start) = start ? monotonic_now - start : 0

        def emit(event, payload, outcome, duration, extras = {})
          subscriber&.call(event, payload.merge(extras, duration:, outcome:, timestamp: Time.now.utc.iso8601))
        end
      end
    end
  end
end
