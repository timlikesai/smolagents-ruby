module Smolagents
  module Orchestrators
    class EventOrchestrator
      # Event routing for the orchestrator.
      #
      # Routes events to registered handlers and triggers work dispatch
      # based on event types.
      module Routing
        # Routes an event to appropriate handlers.
        #
        # @param event [Object] The event to route
        # @return [void]
        def route_event(event)
          @routing_mutex.synchronize do
            track_event(event)
            invoke_handlers(event)
            dispatch_triggered_work(event)
          end
        end

        # Routes multiple events in batch.
        #
        # @param events [Array<Object>] Events to route
        # @return [void]
        def route_batch(events)
          events.each { |event| route_event(event) }
        end

        # Event routing statistics.
        # @return [Hash]
        def routing_stats
          @routing_mutex.synchronize do
            {
              total_routed: @event_stats[:total],
              by_type: @event_stats[:by_type].dup,
              subscription_count: @subscriptions.values.sum(&:size),
              trigger_count: @work_triggers.size
            }
          end
        end

        # Registers a work trigger for an event type.
        #
        # When events of this type are routed, the trigger proc is called
        # to create a work item for dispatch.
        #
        # @param event_type [Class] Event class to trigger on
        # @yield [event] Block that returns a WorkItem or nil
        # @return [self]
        def trigger_work_on(event_type, &block)
          @work_triggers[event_type] = block
          self
        end

        # Removes a work trigger.
        #
        # @param event_type [Class] Event class
        # @return [self]
        def remove_trigger(event_type)
          @work_triggers.delete(event_type)
          self
        end

        private

        def track_event(event)
          @event_stats[:total] += 1
          @event_stats[:by_type][event.class] += 1
        end

        def invoke_handlers(event)
          handlers = @subscriptions[event.class] || []
          handlers.each do |handler|
            invoke_handler(handler, event)
          end
        end

        def invoke_handler(handler, event)
          case handler
          when Proc then handler.call(event)
          when Symbol then send(handler, event)
          else handler.handle(event)
          end
        rescue StandardError => e
          emit_error(e, context: { handler: handler.class.name, event: event.class.name })
        end

        def dispatch_triggered_work(event)
          trigger = @work_triggers[event.class]
          return unless trigger

          work_item = trigger.call(event)
          enqueue_work(work_item) if work_item
        end
      end
    end
  end
end
