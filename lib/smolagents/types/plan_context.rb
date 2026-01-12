module Smolagents
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
