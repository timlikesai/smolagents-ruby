module Smolagents
  module Builders
    # Callback registration methods for ModelBuilder.
    #
    # Uses Events::Subscriptions DSL with hash format for callbacks.
    # Provides chainable methods for model events: failover, error,
    # recovery, model_change, and queue_wait.
    #
    # Method names match CLAUDE.md DSL documentation:
    # - on_failover { }
    # - on_error { }
    # - on_recovery { }
    # - on_model_change { }  (maps to :model_changed event)
    # - on_queue_wait { }    (maps to :queue_request_started event)
    module ModelBuilderCallbacks
      def self.included(base)
        base.include(Events::Subscriptions)
        base.configure_events key: :callbacks, format: :hash
        base.define_handler :failover
        base.define_handler :error
        base.define_handler :recovery
        base.define_handler :model_change, maps_to: :model_changed
        base.define_handler :queue_wait, maps_to: :queue_request_started
      end
    end
  end
end
