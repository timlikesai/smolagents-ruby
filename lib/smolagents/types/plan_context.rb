module Smolagents
  module Types
    # Immutable context for agent planning.
    #
    # PlanContext wraps a plan with metadata about when and how it was
    # generated, and provides methods to check if replanning is needed.
    #
    # @example Creating initial plan context
    #   context = Types::PlanContext.initial("1. Search for information\n2. Summarize")
    #   context.initialized?  # => true
    #
    # @example Checking if plan is stale
    #   if context.stale?(current_step, planning_interval)
    #     context = context.update(new_plan, at_step: current_step)
    #   end
    #
    # @see PlanState For state machine logic
    # @see Concerns::Planning Uses this for plan tracking
    PlanContext = Data.define(:plan, :state, :generated_at, :step_number) do
      class << self
        def initial(plan)
          new(
            plan: plan,
            state: PlanState::INITIAL,
            generated_at: Time.now,
            step_number: 0
          )
        end

        def uninitialized
          new(
            plan: nil,
            state: PlanState::UNINITIALIZED,
            generated_at: nil,
            step_number: nil
          )
        end
      end

      def update(new_plan, at_step:)
        with(
          plan: new_plan,
          state: PlanState::ACTIVE,
          generated_at: Time.now,
          step_number: at_step
        )
      end

      def stale?(current_step, interval)
        PlanState.needs_update?(state, current_step, interval)
      end

      def initialized? = !PlanState.uninitialized?(state)
      def active? = PlanState.active?(state)

      def to_h
        { plan: plan, state: state, generated_at: generated_at&.iso8601, step_number: step_number }.compact
      end
    end
  end
end
