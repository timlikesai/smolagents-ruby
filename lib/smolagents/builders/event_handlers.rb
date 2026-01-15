module Smolagents
  module Builders
    # Event handler subscription methods for builders.
    #
    # Provides convenience methods for subscribing to common events.
    # Included in AgentBuilder and TeamBuilder.
    module EventHandlers
      # Subscribe to step completion events.
      # @yield [event] Step event
      # @return [self] Builder with handler registered
      def on_step(&) = on(:step_complete, &)

      # Subscribe to task completion events.
      # @yield [event] Task event
      # @return [self] Builder with handler registered
      def on_task(&) = on(:task_complete, &)

      # Subscribe to error events.
      # @yield [event] Error event
      # @return [self] Builder with handler registered
      def on_error(&) = on(:error, &)
    end
  end
end
