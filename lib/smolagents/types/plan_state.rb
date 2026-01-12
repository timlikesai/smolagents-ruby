module Smolagents
  module PlanState
    UNINITIALIZED = :uninitialized
    INITIAL = :initial
    ACTIVE = :active
    UPDATING = :updating

    ALL = [UNINITIALIZED, INITIAL, ACTIVE, UPDATING].freeze

    class << self
      def uninitialized?(state) = state == UNINITIALIZED
      def initial?(state) = state == INITIAL
      def active?(state) = state == ACTIVE
      def updating?(state) = state == UPDATING

      def valid?(state) = ALL.include?(state)

      def needs_update?(state, step_number, interval)
        return false unless interval&.positive?
        return true if uninitialized?(state)

        (step_number % interval).zero?
      end

      def transition(current_state, has_plan:)
        return INITIAL if uninitialized?(current_state) && !has_plan
        return ACTIVE if initial?(current_state) && has_plan
        return ACTIVE if updating?(current_state) && has_plan

        current_state
      end
    end
  end
end
