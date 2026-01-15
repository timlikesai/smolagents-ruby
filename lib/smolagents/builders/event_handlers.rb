module Smolagents
  module Builders
    # Event subscription methods for agent and team builders.
    #
    # Uses Events::Subscriptions DSL to provide:
    # - Base on(event_type, &block) method
    # - Common convenience methods (on_step, on_task, on_error)
    #
    # Individual builders can add their own define_handler calls for
    # builder-specific events (e.g., on_tool, on_agent).
    module EventHandlers
      def self.included(base)
        base.include(Events::Subscriptions)
        base.configure_events key: :handlers, format: :tuple
        base.define_handler :step, maps_to: :step_complete
        base.define_handler :task, maps_to: :task_complete
        base.define_handler :error
        base.define_handler :control_yielded
        base.define_handler :control_resumed
      end
    end
  end
end
