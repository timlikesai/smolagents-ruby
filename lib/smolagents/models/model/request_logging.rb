# Request logging for model calls.

module Smolagents
  module Models
    class Model
      # Tracks model generation requests for debugging and analysis.
      #
      # When enabled, captures each generate call as a RequestLog entry
      # that can be queried after execution.
      #
      # @example Enabling request logging
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_request_logging
      #     .build
      #
      #   agent.run("task")
      #
      #   model.request_logs.each { |log| puts log.total_tokens }
      #
      # @see Types::RequestLog The log entry type
      module RequestLogging
        def self.included(base)
          base.attr_reader :request_logs
        end

        # Initializes request logging state.
        # Call this from model constructor when logging is enabled.
        def initialize_request_logging
          @request_logs = []
          @pending_request = nil
          @request_logging_mutex = Mutex.new
        end

        # Checks if request logging is enabled.
        # @return [Boolean]
        def request_logging? = defined?(@request_logs) && !@request_logs.nil?

        # Returns recent request logs.
        #
        # @param count [Integer] Number of logs to return (default: all)
        # @return [Array<Types::RequestLog>]
        def last_requests(count = nil)
          return @request_logs.dup unless count

          @request_logs.last(count)
        end

        # Clears all request logs.
        # @return [self]
        def clear_request_logs
          @request_logging_mutex.synchronize { @request_logs.clear }
          self
        end

        # Total tokens used across all logged requests.
        # @return [Integer]
        def total_tokens_used
          @request_logs.sum { |log| log.total_tokens || 0 }
        end

        # Total duration across all logged requests.
        # @return [Integer] Milliseconds
        def total_duration_ms
          @request_logs.sum { |log| log.duration_ms || 0 }
        end

        # Filters logs by outcome.
        #
        # @param outcome [Symbol] :success or :error
        # @return [Array<Types::RequestLog>]
        def requests_with_outcome(outcome)
          @request_logs.select { |log| log.outcome == outcome }
        end

        # Returns logs since a timestamp.
        #
        # @param time [Time] Start time
        # @return [Array<Types::RequestLog>]
        def requests_since(time)
          @request_logs.select { |log| log.timestamp > time }
        end

        # Wraps event emission to capture request logs.
        #
        # Override of Eventing#with_generate_events to intercept events.
        def with_generate_events(messages, options = {}, &)
          return super unless request_logging?

          capture_request_events(messages, options) { super(messages, options, &) }
        end

        private

        def capture_request_events(messages, options)
          requested_event = build_requested_event(messages, options)
          @pending_request = requested_event

          result = yield
          record_completed_request(requested_event)
          result
        rescue StandardError => e
          record_failed_request(requested_event) if requested_event
          raise e
        end

        def build_requested_event(messages, options)
          Events::ModelGeneration.create(
            phase: :requested,
            model_id:,
            message_count: messages.size,
            has_tools: !options[:tools_to_call_from].nil? && !options[:tools_to_call_from].empty?,
            temperature: options[:temperature] || @temperature
          )
        end

        def record_completed_request(requested_event)
          @request_logging_mutex.synchronize do
            # Build a completion event from the pending request
            completed_event = build_completion_event(requested_event)
            log = Types::RequestLog.from_events(requested_event, completed_event)
            @request_logs << log
          end
        end

        def record_failed_request(requested_event)
          @request_logging_mutex.synchronize do
            completed_event = build_completion_event(requested_event, outcome: :error)
            log = Types::RequestLog.from_events(requested_event, completed_event)
            @request_logs << log
          end
        end

        def build_completion_event(requested_event, outcome: :success)
          duration_ms = ((Time.now - requested_event.created_at) * 1000).to_i
          Events::ModelGeneration.create(
            phase: :completed,
            model_id:,
            duration_ms:,
            token_usage: nil,
            has_tool_calls: false,
            outcome:
          )
        end
      end
    end
  end
end
