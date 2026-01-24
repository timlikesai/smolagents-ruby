module Smolagents
  module Builders
    # Goals configuration DSL methods for AgentBuilder.
    #
    # Extracted to keep builder focused on composition.
    module GoalsConcern
      # Configure goal tracking.
      #
      # Goals track what the agent is trying to accomplish. When enabled,
      # the agent's task becomes its root goal, and subgoals can be created
      # as work is decomposed.
      #
      # @overload goals
      #   Enable goal tracking with defaults
      #   @return [AgentBuilder]
      #
      # @overload goals(enabled)
      #   Enable or disable goal tracking
      #   @param enabled [Boolean] Whether to enable goals
      #   @return [AgentBuilder]
      #
      # @overload goals(visible:)
      #   Configure with named parameters
      #   @param visible [Boolean] Show goals in output (default: false)
      #   @return [AgentBuilder]
      #
      # @example Enable with defaults
      #   builder = Smolagents.agent.goals
      #   builder.config[:goal_config].enabled
      #   #=> true
      #
      # @example Enable with visibility
      #   builder = Smolagents.agent.goals(visible: true)
      #   builder.config[:goal_config].visible
      #   #=> true
      #
      # @example Disable goals
      #   builder = Smolagents.agent.goals(false)
      #   builder.config[:goal_config].enabled
      #   #=> false
      def goals(enabled = :_default_, visible: false)
        check_frozen!

        config = resolve_goal_config(enabled, visible)
        with_config(goal_config: config)
      end

      private

      # Resolve goal config from arguments.
      # @param enabled [Boolean, Symbol] Whether to enable
      # @param visible [Boolean] Whether to show in output
      # @return [Types::GoalConfig] Resolved configuration
      def resolve_goal_config(enabled, visible)
        case enabled
        when :_default_, true, :enabled, :on
          Types::GoalConfig.new(enabled: true, visible:)
        when false, :disabled, :off
          Types::GoalConfig.disabled
        else
          raise ArgumentError, "Invalid goals argument: #{enabled.inspect}. Use true/false or :enabled/:disabled."
        end
      end
    end
  end
end
