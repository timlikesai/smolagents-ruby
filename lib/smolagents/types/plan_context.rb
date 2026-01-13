module Smolagents
  module Types
    # Immutable context for agent planning.
    #
    # Wraps a plan with metadata about when and how it was generated,
    # including state machine tracking and convenience methods for checking
    # if replanning is needed.
    #
    # @example Creating initial plan context
    #   context = Types::PlanContext.initial("1. Search for information\n2. Summarize")
    #   context.initialized?  # => true
    #
    # @example Checking if plan is stale and updating
    #   if context.stale?(current_step, planning_interval)
    #     context = context.update(new_plan, at_step: current_step)
    #   end
    #
    # @example Creating uninitialized context
    #   context = PlanContext.uninitialized
    #   context.initialized?  # => false
    #
    # @see PlanState For state machine logic
    # @see Concerns::Planning Uses this for plan tracking
    PlanContext = Data.define(:plan, :state, :generated_at, :step_number) do
      class << self
        # Creates a PlanContext with an initial plan.
        #
        # Sets state to INITIAL and generated_at to current time.
        #
        # @param plan [String] The initial plan text
        # @return [PlanContext] Context with initial plan
        # @example
        #   context = PlanContext.initial("1. Search\n2. Synthesize")
        def initial(plan)
          new(
            plan: plan,
            state: PlanState::INITIAL,
            generated_at: Time.now,
            step_number: 0
          )
        end

        # Creates a PlanContext with no plan yet.
        #
        # Sets state to UNINITIALIZED for context that needs initial plan generation.
        #
        # @return [PlanContext] Uninitialized context
        # @example
        #   context = PlanContext.uninitialized
        def uninitialized
          new(
            plan: nil,
            state: PlanState::UNINITIALIZED,
            generated_at: nil,
            step_number: nil
          )
        end
      end

      # Updates context with a new plan.
      #
      # Transitions state to ACTIVE and records generation time and step number.
      #
      # @param new_plan [String] The updated plan text
      # @param at_step [Integer] Step number when plan was generated
      # @return [PlanContext] New context with updated plan
      # @example
      #   context = context.update("1. Revised plan...", at_step: 5)
      def update(new_plan, at_step:)
        with(
          plan: new_plan,
          state: PlanState::ACTIVE,
          generated_at: Time.now,
          step_number: at_step
        )
      end

      # Checks if plan should be updated.
      #
      # Delegates to PlanState to check if replanning interval indicates
      # a new plan is needed.
      #
      # @param current_step [Integer] Current step number
      # @param interval [Integer, nil] Replanning interval (nil disables)
      # @return [Boolean] True if plan is stale and needs updating
      # @example
      #   if context.stale?(step, 3)
      #     context = context.update(new_plan, at_step: step)
      #   end
      def stale?(current_step, interval)
        PlanState.needs_update?(state, current_step, interval)
      end

      # Checks if a plan has been initialized.
      #
      # @return [Boolean] True if state is not UNINITIALIZED
      # @example
      #   context.initialized?  # => true if plan exists
      def initialized? = !PlanState.uninitialized?(state)

      # Checks if plan is currently active.
      #
      # @return [Boolean] True if state is ACTIVE
      # @example
      #   context.active?  # => true if executing with plan
      def active? = PlanState.active?(state)

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :plan, :state, :generated_at (ISO8601), :step_number
      # @example
      #   context.to_h  # => { plan: "...", state: :active, generated_at: "...", step_number: 5 }
      def to_h
        { plan: plan, state: state, generated_at: generated_at&.iso8601, step_number: step_number }.compact
      end
    end
  end
end
