module Smolagents
  module Concerns
    # Budget tracking for code execution steps.
    #
    # Provides step budget reminders to help the model understand when
    # it needs to wrap up and provide a final answer.
    #
    # @see CodeExecution For the main execution flow
    module BudgetTracking
      private

      # Appends budget reminder to observations when running low on steps.
      # Helps models know when to wrap up without explicit puts(budget).
      def with_budget_reminder(action_step, logs)
        return logs unless @max_steps

        remaining = calculate_remaining_steps(action_step)

        if remaining <= 0
          "#{logs}\n[URGENT: This is your LAST step. Call final_answer NOW.]"
        elsif remaining <= 2
          "#{logs}\n[Budget: #{remaining} step#{"s" if remaining > 1} remaining]"
        else
          logs
        end
      end

      def calculate_remaining_steps(action_step)
        step_num = action_step.step_number || 0
        @max_steps - step_num - 1 # -1 because this step is done
      end
    end
  end
end
