# Shared event infrastructure - queue connection and event resolution.

require_relative "mappings"
require_relative "async_queue"

module Smolagents
  module Events
    # Base event functionality shared by Emitter and Consumer.
    #
    # Provides queue connection and event class resolution.
    # Not typically included directly - use Emitter, Consumer, or Eventful.
    #
    module Base
      def self.included(base)
        base.attr_accessor :event_queue
      end

      # Connects to an external event queue.
      # @param queue [Thread::Queue]
      # @return [self]
      def connect_to(queue)
        @event_queue = queue
        self
      end

      # Checks if event emission/consumption is active.
      # @return [Boolean]
      def emitting? = !!(@event_queue || @event_handlers&.any?)

      private

      # Resolves event name to class, or passes through unknown symbols/classes.
      def resolve_event_class(name_or_class)
        return name_or_class if name_or_class.is_a?(Class)

        if Mappings.valid?(name_or_class)
          Mappings.resolve(name_or_class)
        else
          name_or_class
        end
      end

      # Builds an event from symbol name and kwargs.
      def build_event(name, kwargs)
        event_class = resolve_event_class(name)
        event_class.create(**kwargs)
      end
    end
  end
end
