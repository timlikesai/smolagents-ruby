module Smolagents
  module Events
    # Producer trait for event-driven components.
    #
    # Any class that produces events can include this module to get
    # standardized event emission capabilities. Events are pushed to
    # a configured event queue (the "channel").
    #
    # Think of this like a Kafka producer or SNS publisher:
    # - Producers emit events without knowing who consumes them
    # - Events go to a queue/topic
    # - Consumers subscribe to receive events
    #
    # @example Tool as event producer
    #   class SearchTool < Tool
    #     include Events::Emitter
    #
    #     def execute(query:)
    #       emit_event(Events::ToolCallRequested.create(tool_name: name, args: { query: }))
    #       result = perform_search(query)
    #       emit_event(Events::ToolCallCompleted.create(result:, observation: "Found #{result.size} results"))
    #       result
    #     end
    #   end
    #
    # @example Model as event producer
    #   class AnthropicModel < Model
    #     include Events::Emitter
    #
    #     def generate(messages, **)
    #       request_event = emit_event(Events::ModelGenerateRequested.create(messages:))
    #       response = call_api(messages)
    #       emit_event(Events::ModelGenerateCompleted.create(request_id: request_event.id, response:))
    #       response
    #     end
    #   end
    #
    module Emitter
      def self.included(base)
        base.attr_accessor :event_queue
      end

      # Connect this emitter to an event queue.
      #
      # @param queue [EventQueue] The queue to emit events to
      # @return [self] For chaining
      def connect_to(queue)
        @event_queue = queue
        self
      end

      # Emit an event to the configured queue.
      #
      # @param event [Object] Event to emit
      # @param priority [Symbol] Queue priority (:error, :immediate, :scheduled, :background)
      # @return [Object] The emitted event (for chaining/tracking)
      def emit_event(event, priority: :immediate)
        @event_queue&.push(event, priority:)
        event
      end

      # Emit a rate limit event and return the scheduled retry.
      #
      # @param tool_name [String] Name of the rate-limited tool
      # @param retry_after [Float] Seconds until retry
      # @param original_request [Object] The original request to retry
      # @return [RateLimitHit] The scheduled event
      def emit_rate_limit(tool_name:, retry_after:, original_request:)
        event = RateLimitHit.create(
          tool_name:,
          retry_after:,
          original_request:
        )
        emit_event(event, priority: :scheduled)
      end

      # Emit an error event.
      #
      # @param error [Exception] The error that occurred
      # @param context [Hash] Additional context
      # @param recoverable [Boolean] Whether the error is recoverable
      # @return [ErrorOccurred] The error event
      def emit_error(error, context: {}, recoverable: false)
        event = ErrorOccurred.create(error:, context:, recoverable:)
        emit_event(event, priority: :error)
      end

      # Emit a sub-agent progress event.
      #
      # @param launch_id [String] The launch event id
      # @param agent_name [String] Name of the sub-agent
      # @param step_number [Integer] Current step number
      # @param message [String] Progress message
      # @return [SubAgentProgress] The progress event
      def emit_sub_agent_progress(launch_id:, agent_name:, step_number:, message:)
        event = SubAgentProgress.create(
          launch_id:,
          agent_name:,
          step_number:,
          message:
        )
        emit_event(event, priority: :immediate)
      end

      # Check if connected to a queue.
      #
      # @return [Boolean] True if event_queue is set
      def emitting?
        !@event_queue.nil?
      end
    end
  end
end
