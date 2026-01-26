module Smolagents
  module Agents
    class Agent
      # Runtime delegation methods for Agent.
      #
      # Provides access to runtime state, planning configuration, and other
      # delegated concerns. Keeps the main Agent class thin by forwarding
      # to the appropriate component.
      #
      # @api private
      module Delegation
        # Registers an event handler on both the agent and runtime.
        #
        # This ensures handlers fire whether consuming events from a queue
        # (which calls agent.consume) or emitting sync events (which calls
        # runtime.consume).
        #
        # @param event_type [Symbol, Class] Event type identifier or class
        # @yield [event] Block to call when event occurs
        # @return [self]
        def on(event_type, &)
          super
          @runtime&.on(event_type, &)
          self
        end

        # Returns the runtime's internal state hash.
        #
        # @return [Hash] Mutable state hash from the runtime
        def state = @runtime.instance_variable_get(:@state)

        # Returns the planning interval (steps between replanning).
        #
        # @return [Integer, nil] Steps between planning phases, or nil if disabled
        def planning_interval = @runtime.planning_interval

        # Returns the planning templates configuration.
        #
        # @return [Hash, nil] Planning prompt templates
        def planning_templates = @runtime.planning_templates

        private

        # Delegate plan_context access to runtime for compatibility.
        #
        # @return [PlanContext] The runtime's plan context
        def plan_context = @runtime.send(:plan_context)
      end
    end
  end
end
