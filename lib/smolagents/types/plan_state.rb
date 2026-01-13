module Smolagents
  module Types
    # State machine for agent planning phases.
    #
    # PlanState defines the lifecycle of agent planning, from initialization
    # through active execution with periodic replanning. Supports the full
    # planning cycle: uninitialized → initial (generate plan) → active
    # (execute and update periodically) → updating → active again.
    #
    # @example Checking if plan needs update
    #   if Types::PlanState.needs_update?(state, step_number, interval)
    #     agent.generate_plan
    #   end
    #
    # @example Checking current state
    #   if PlanState.active?(state)
    #     puts "Agent is executing with active plan"
    #   end
    #
    # @see PlanContext Wraps planning state with context
    # @see Concerns::Planning Uses these states during execution
    module PlanState
      # No plan generated yet, initial generation needed.
      UNINITIALIZED = :uninitialized

      # Initial plan just generated, ready for execution.
      INITIAL = :initial

      # Active plan, currently executing.
      ACTIVE = :active

      # Plan being updated, will return to ACTIVE.
      UPDATING = :updating

      # @return [Array<Symbol>] All valid planning states
      ALL = [UNINITIALIZED, INITIAL, ACTIVE, UPDATING].freeze

      class << self
        # Checks if planning state is uninitialized.
        #
        # @param state [Symbol] State to check
        # @return [Boolean] True if state is :uninitialized
        # @example
        #   PlanState.uninitialized?(:uninitialized)  # => true
        def uninitialized?(state) = state == UNINITIALIZED

        # Checks if planning state is initial.
        #
        # @param state [Symbol] State to check
        # @return [Boolean] True if state is :initial
        # @example
        #   PlanState.initial?(:initial)  # => true
        def initial?(state) = state == INITIAL

        # Checks if planning state is active.
        #
        # @param state [Symbol] State to check
        # @return [Boolean] True if state is :active
        # @example
        #   PlanState.active?(:active)  # => true
        def active?(state) = state == ACTIVE

        # Checks if planning state is updating.
        #
        # @param state [Symbol] State to check
        # @return [Boolean] True if state is :updating
        # @example
        #   PlanState.updating?(:updating)  # => true
        def updating?(state) = state == UPDATING

        # Validates if state is a known planning state.
        #
        # @param state [Symbol] State to check
        # @return [Boolean] True if state is in ALL
        # @example
        #   PlanState.valid?(:active)  # => true
        #   PlanState.valid?(:unknown)  # => false
        def valid?(state) = ALL.include?(state)

        # Determines if plan needs updating.
        #
        # Returns true if uninitialized (plan needed) or if step number
        # is a multiple of interval.
        #
        # @param state [Symbol] Current planning state
        # @param step_number [Integer] Current step number
        # @param interval [Integer, nil] Steps between updates (nil disables)
        # @return [Boolean] True if plan should be updated
        # @example
        #   PlanState.needs_update?(:uninitialized, 5, 3)  # => true
        #   PlanState.needs_update?(:active, 6, 3)  # => true (6 % 3 == 0)
        #   PlanState.needs_update?(:active, 5, 3)  # => false
        #   PlanState.needs_update?(:active, 5, nil)  # => false
        def needs_update?(state, step_number, interval)
          return false unless interval&.positive?
          return true if uninitialized?(state)

          (step_number % interval).zero?
        end

        # Transitions to next planning state.
        #
        # State transitions:
        # - UNINITIALIZED → INITIAL (when plan provided)
        # - INITIAL → ACTIVE (when plan provided)
        # - UPDATING → ACTIVE (when plan provided)
        # - Otherwise stays the same
        #
        # @param current_state [Symbol] Current planning state
        # @param has_plan [Boolean] Whether a plan is available
        # @return [Symbol] Next planning state
        # @example
        #   PlanState.transition(:uninitialized, has_plan: true)  # => :initial
        #   PlanState.transition(:initial, has_plan: true)  # => :active
        #   PlanState.transition(:active, has_plan: false)  # => :active
        def transition(current_state, has_plan:)
          return INITIAL if uninitialized?(current_state) && !has_plan
          return ACTIVE if initial?(current_state) && has_plan
          return ACTIVE if updating?(current_state) && has_plan

          current_state
        end
      end
    end
  end
end
