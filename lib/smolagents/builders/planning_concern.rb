module Smolagents
  module Builders
    # Planning configuration DSL methods for AgentBuilder.
    #
    # Extracted to keep builder focused on composition.
    module PlanningConcern
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
      #   .planning                      # interval: 3 (research-backed default)
      #
      # @example Enable with custom interval
      #   .planning(5)                   # re-plan every 5 steps
      #
      # @example Explicit enable/disable
      #   .planning(true)                # same as .planning
      #   .planning(false)               # disable planning
      #   .planning(:enabled)            # same as .planning
      #   .planning(:disabled)           # disable planning
      #
      # @example Full configuration
      #   .planning(interval: 3, templates: { initial_plan: "..." })
      #
      def planning(interval_or_enabled = :_default_, interval: nil, templates: nil)
        check_frozen!

        resolved_interval = resolve_planning_interval(interval_or_enabled, interval)

        with_config(
          planning_interval: resolved_interval,
          planning_templates: templates || configuration[:planning_templates]
        )
      end

      private

      def resolve_planning_interval(positional, named)
        return named if named

        case positional
        when :_default_, true, :enabled, :on then Config::DEFAULT_PLANNING_INTERVAL
        when Integer then positional
        when false, :disabled, :off, nil then nil
        else invalid_planning_arg!(positional)
        end
      end

      def invalid_planning_arg!(value)
        raise ArgumentError, <<~ERROR.gsub(/\s+/, " ").strip
          Invalid planning argument: #{value.inspect}.
          Use Integer, true/false, :enabled/:disabled, or interval: keyword.
        ERROR
      end
    end
  end
end
