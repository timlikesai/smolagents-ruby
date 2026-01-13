module Smolagents
  module Events
    # Scheduling DSL for event-driven operations.
    #
    # Provides time-based scheduling without sleeps. Events can be scheduled
    # for future execution, and the master loop processes them when ready.
    #
    # Key concepts:
    # - schedule: Add an event with a future due time
    # - due: When the event should be processed
    # - past_due: Events that have exceeded their allowed wait time
    #
    # @example Scheduling a retry
    #   scheduler.schedule_retry(request, retry_after: 1.0)
    #   # Event will be ready in 1 second
    #
    # @example Scheduling at specific time
    #   scheduler.schedule_at(event, Time.now + 5)
    #   # Event will be ready in 5 seconds
    #
    # @example Handling stale events
    #   expired = scheduler.handle_stale_events(threshold: 60)
    #   # Returns events that were past due by more than 60 seconds
    #
    module Scheduler
      def self.included(base)
        base.attr_reader :event_queue unless base.method_defined?(:event_queue)
      end

      # Schedule an event for future execution.
      #
      # @param event [Object] Event to schedule (will have due_at set)
      # @param delay [Float, nil] Seconds from now
      # @param at [Time, nil] Specific time
      # @param priority [Symbol] Queue priority
      # @return [Object] The scheduled event (possibly modified)
      def schedule(event, delay: nil, at: nil, priority: :scheduled)
        due_at = at || (delay ? Time.now + delay : nil)

        scheduled = if event.respond_to?(:with) && due_at
                      event.with(due_at:)
                    else
                      event
                    end

        event_queue.push(scheduled, priority:)
        scheduled
      end

      # Schedule an event at a specific time.
      #
      # @param event [Object] Event to schedule
      # @param time [Time] When to process
      # @param priority [Symbol] Queue priority
      # @return [Object] The scheduled event
      def schedule_at(event, time, priority: :scheduled)
        schedule(event, at: time, priority:)
      end

      # Schedule an event after a delay.
      #
      # @param event [Object] Event to schedule
      # @param seconds [Float] Delay in seconds
      # @param priority [Symbol] Queue priority
      # @return [Object] The scheduled event
      def schedule_after(event, seconds, priority: :scheduled)
        schedule(event, delay: seconds, priority:)
      end

      # Schedule a retry after rate limit.
      #
      # @param original_request [Object] The original request event
      # @param retry_after [Float] Seconds to wait
      # @param tool_name [String] Name of the rate-limited tool
      # @return [RateLimitHit] The scheduled rate limit event
      def schedule_retry(original_request, retry_after:, tool_name: nil)
        event = RateLimitHit.create(
          tool_name: tool_name || original_request.tool_name,
          retry_after:,
          original_request:
        )
        event_queue.push(event, priority: :scheduled)
        event
      end

      # Check for and handle stale events.
      #
      # Removes events that are past due by more than the threshold,
      # and emits EventExpired events for each.
      #
      # @param threshold [Integer] Seconds past due to consider stale
      # @return [Array<EventExpired>] Expired event notifications
      def handle_stale_events(threshold: 60)
        stale = event_queue.cleanup_stale(threshold:)
        stale.map do |event|
          expired = EventExpired.create(original_event: event, threshold:)
          trigger_callbacks(:on_event_expired, event: expired) if respond_to?(:trigger_callbacks, true)
          expired
        end
      end

      # Time until next scheduled event.
      #
      # @return [Float, nil] Seconds until next event, or nil if none scheduled
      def next_scheduled_in
        event_queue.next_due_in
      end

      # Check if there are ready events.
      #
      # @return [Boolean] True if events are ready to process
      def events_ready?
        event_queue.ready?
      end

      # Count of ready events.
      #
      # @return [Integer] Number of ready events
      def ready_event_count
        event_queue.ready_count
      end

      # Process ready events up to limit.
      #
      # @param max [Integer] Maximum events to process
      # @yield [event] Block to handle each event
      # @return [Array<Object>] Processed events
      def process_ready_events(max: 10, &block)
        events = event_queue.drain(max:)
        events.each(&block) if block
        events
      end

      # Cancel scheduled events matching criteria.
      #
      # @yield [event] Block that returns true for events to cancel
      # @return [Array<Object>] Cancelled events
      def cancel_scheduled(&)
        event_queue.remove_if(&)
      end

      # Cancel all events for a specific tool.
      #
      # @param tool_name [String] Tool name to cancel
      # @return [Array<Object>] Cancelled events
      def cancel_tool_events(tool_name)
        cancel_scheduled do |event|
          event.respond_to?(:tool_name) && event.tool_name == tool_name
        end
      end
    end
  end
end
