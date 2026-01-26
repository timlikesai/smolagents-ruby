require_relative "../../types/orchestrators/subscription"

module Smolagents
  module Orchestrators
    class EventOrchestrator
      # Subscription management for the orchestrator.
      #
      # Handles registration, lookup, and removal of event subscriptions.
      module Subscriptions
        # Subscribes a handler to an event type.
        #
        # @param event_type [Symbol, Class] Event type or class
        # @param handler [Object, nil] Handler object (responds to #handle)
        # @yield [event] Block handler
        # @return [String] Subscription ID
        def subscribe(event_type, handler = nil, &block)
          event_class = resolve_event_class(event_type)
          subscription = build_subscription(event_class, handler || block)
          register_subscription(subscription)
          subscription.id
        end

        # Unsubscribes a handler by ID.
        #
        # @param subscription_id [String] The subscription ID
        # @return [Boolean] True if found and removed
        def unsubscribe(subscription_id)
          @subscriptions_mutex.synchronize do
            subscription = @subscription_index.delete(subscription_id)
            return false unless subscription

            handlers = @subscriptions[subscription.event_class]
            handlers&.delete(subscription.handler)
            true
          end
        end

        # Lists all subscriptions for an event type.
        #
        # @param event_type [Symbol, Class] Event type or class
        # @return [Array<String>] Subscription IDs
        def subscriptions_for(event_type)
          event_class = resolve_event_class(event_type)
          @subscriptions_mutex.synchronize do
            @subscription_index.values
                               .select { |s| s.event_class == event_class }
                               .map(&:id)
          end
        end

        # Clears all subscriptions.
        #
        # @return [self]
        def clear_subscriptions
          @subscriptions_mutex.synchronize do
            @subscriptions.clear
            @subscription_index.clear
          end
          self
        end

        # Returns subscription statistics.
        # @return [Hash]
        def subscription_stats
          @subscriptions_mutex.synchronize do
            {
              total: @subscription_index.size,
              by_event: @subscriptions.transform_values(&:size)
            }
          end
        end

        private

        def build_subscription(event_class, handler)
          Subscription.new(id: SecureRandom.uuid, event_class:, handler:)
        end

        def register_subscription(subscription)
          @subscriptions_mutex.synchronize do
            (@subscriptions[subscription.event_class] ||= []) << subscription.handler
            @subscription_index[subscription.id] = subscription
          end
        end

        def resolve_event_class(event_type)
          return event_type if event_type.is_a?(Class)

          Events::Mappings.resolve(event_type)
        end
      end
    end
  end
end
