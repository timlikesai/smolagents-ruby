module Smolagents
  module Builders
    # Planning configuration DSL methods for AgentBuilder.
    #
    # Extracted to keep builder focused on composition.
    module PlanningConcern
      include Support::FlexibleInput

      # Configure planning (Pre-Act pattern).
      #
      # Research shows 70% improvement in Action Recall with planning enabled.
      # Planning creates a strategic plan before execution and updates it periodically.
      #
      # @overload planning
      #   Enable planning with default interval (3 steps)
      #   @return [AgentBuilder]
      #
      # @overload planning(interval_or_enabled)
      #   Enable planning with specific interval or toggle
      #   @param interval_or_enabled [Integer, Boolean, Symbol] Interval, true/:enabled, or false/:disabled
      #   @return [AgentBuilder]
      #
      # @overload planning(interval:, templates:)
      #   Full configuration with named parameters
      #   @param interval [Integer, nil] Steps between re-planning (default: 3)
      #   @param templates [Hash, nil] Custom planning prompt templates
      #   @return [AgentBuilder]
      #
      # @example Enable with defaults
      #   builder = Smolagents.agent.planning
      #   builder.config[:planning_interval]
      #   #=> 3
      #
      # @example Enable with custom interval
      #   builder = Smolagents.agent.planning(5)
      #   builder.config[:planning_interval]
      #   #=> 5
      #
      # @example Disable planning
      #   builder = Smolagents.agent.planning(false)
      #   builder.config[:planning_interval]
      #   #=> nil
      #
      # @example Full configuration with named parameters
      #   builder = Smolagents.agent.planning(interval: 7)
      #   builder.config[:planning_interval]
      #   #=> 7
      def planning(value = UNSET, interval: nil, templates: nil)
        check_frozen!
        resolved = resolve_value_or_toggle(
          value, interval, value_type: Integer, default: Config::DEFAULT_PLANNING_INTERVAL, name: "planning"
        )
        with_config(planning_interval: resolved, planning_templates: templates || configuration[:planning_templates])
      end
    end
  end
end
