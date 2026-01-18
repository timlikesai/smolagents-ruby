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
      # Handler definitions: name => maps_to (nil means identity mapping)
      HANDLERS = {
        step: :step_complete, task: :task_complete, error: nil,
        control_yielded: nil, control_resumed: nil,
        tool_isolation_started: nil, tool_isolation_completed: nil, resource_violation: nil,
        isolation: :tool_isolation_completed, violation: :resource_violation
      }.freeze

      def self.included(base)
        base.include(Events::Subscriptions)
        base.configure_events key: :handlers, format: :tuple
        HANDLERS.each { |name, maps_to| base.define_handler(name, maps_to: maps_to || name) }
      end
    end
  end
end
