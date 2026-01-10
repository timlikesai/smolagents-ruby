# frozen_string_literal: true

module Smolagents
  # Shared step execution pattern for agents.
  module StepExecution
    def with_step_timing(step_number: 0)
      action_step = ActionStep.new(step_number: step_number)
      action_step.timing = Timing.start_now

      begin
        yield action_step
      rescue StandardError => e
        action_step.error = "#{e.class}: #{e.message}"
        @logger.error("Step error", error: e.message)
      end

      action_step.timing = action_step.timing.stop
      action_step
    end
  end
end
