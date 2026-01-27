# Storable concern - integrates EventStore with Emitter.

module Smolagents
  module Events
    class EventStore
      # Mixin that adds automatic event persistence to any Emitter.
      #
      # When included alongside Events::Emitter, emitted events are
      # automatically appended to the configured EventStore.
      #
      # @example Storable agent
      #   class MyAgent
      #     include Events::Emitter
      #     include EventStore::Storable
      #
      #     def initialize(store)
      #       self.event_store = store
      #     end
      #
      #     def work
      #       emit :step_complete, step_number: 1  # Auto-persisted
      #     end
      #   end
      #
      # @see Events::Emitter Base emission functionality
      # @see EventStore Event storage
      module Storable
        def self.included(base)
          base.attr_accessor :event_store
        end

        # Emits an event and persists to store if configured.
        #
        # Overrides Emitter#emit to add store persistence.
        # Falls back to standard emit behavior when no store.
        def emit(event_or_name, **kwargs, &)
          # Build the event first if it's a symbol
          event = if event_or_name.is_a?(Symbol)
                    build_event(event_or_name, kwargs)
                  else
                    event_or_name
                  end

          # Call parent emit with the built event
          result = block_given? ? super(event, &) : super(event)

          # Persist to store if configured
          persist_to_store(event) if event && @event_store

          result.is_a?(Symbol) ? event : result
        end

        # Emits synchronously and persists.
        def emit!(event_or_name, **kwargs, &)
          event = if event_or_name.is_a?(Symbol)
                    build_event(event_or_name, kwargs)
                  else
                    event_or_name
                  end

          result = block_given? ? super(event, &) : super(event)
          persist_to_store(event) if event && @event_store

          result.is_a?(Symbol) ? event : result
        end

        # Configures the event store.
        #
        # @param store [EventStore] Store instance
        # @return [self]
        def persist_to(store)
          @event_store = store
          self
        end

        private

        def persist_to_store(event)
          @event_store.append(event)
        rescue StandardError
          # Storage errors should not break emission
        end
      end
    end
  end
end
