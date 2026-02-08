module Smolagents
  module Concerns
    module Resilience
      # Subscribes to error events and stores recent FailureSnapshot instances.
      #
      # Provides a bounded, thread-safe circular buffer of failure snapshots
      # for debugging. Subscribes to +:error_occurred+ events via the Consumer
      # protocol and captures context (model_id, step_number, request/response).
      #
      # @example Including in a class
      #   class MyAgent
      #     include Events::Consumer
      #     include Concerns::Resilience::FailureCapture
      #
      #     def initialize
      #       initialize_failure_capture(max_failures: 10)
      #     end
      #   end
      #
      # @see Types::FailureSnapshot For the snapshot data type
      module FailureCapture
        DEFAULT_MAX_FAILURES = 5

        def self.included(base)
          base.include(Events::Consumer)
        end

        # Returns all captured failure snapshots (newest last).
        # @return [Array<Types::FailureSnapshot>]
        def last_failures
          @failure_mutex.synchronize { @failures.dup }
        end

        # Returns the most recent failure snapshot.
        # @return [Types::FailureSnapshot, nil]
        def last_failure
          @failure_mutex.synchronize { @failures.last }
        end

        # Number of captured failures.
        # @return [Integer]
        def failure_count
          @failure_mutex.synchronize { @failures.size }
        end

        # Clear all captured failures.
        # @return [self]
        def clear_failures!
          @failure_mutex.synchronize { @failures.clear }
          self
        end

        private

        # Initialize failure capture with configurable buffer size.
        # @param max_failures [Integer] Maximum snapshots to retain
        def initialize_failure_capture(max_failures: DEFAULT_MAX_FAILURES)
          @failures = []
          @max_failures = max_failures
          @failure_mutex = Mutex.new
          subscribe_failure_events
        end

        def subscribe_failure_events
          on(:error_occurred) { |event| capture_failure(event) }
        end

        def capture_failure(event) = store_failure(build_failure_snapshot(event))

        def build_failure_snapshot(event)
          ctx = event.context || {}
          Types::FailureSnapshot.new(
            timestamp: Time.now,
            model_id: ctx[:model_id]&.to_s,
            error_class: event.error_class,
            error_message: truncate_failure_str(event.error_message, 500),
            request_summary: truncate_failure_str(ctx[:request_summary]&.to_s, 500),
            response_summary: truncate_failure_str(ctx[:response_summary]&.to_s, 500),
            step_number: ctx[:step_number]
          )
        end

        def store_failure(snapshot)
          @failure_mutex.synchronize do
            @failures << snapshot
            @failures.shift if @failures.size > @max_failures
          end
        end

        def truncate_failure_str(str, max)
          return nil if str.nil? || str.empty?

          str.length > max ? "#{str[0, max - 3]}..." : str
        end
      end
    end
  end
end
