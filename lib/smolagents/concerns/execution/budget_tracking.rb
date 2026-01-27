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
      # Progressive urgency: gentle at 4 steps, urgent at 1, critical at 0.
      def with_budget_reminder(action_step, logs)
        return logs unless @max_steps

        remaining = calculate_remaining_steps(action_step)

        reminder = budget_reminder_for(remaining)
        reminder ? "#{logs}\n#{reminder}" : logs
      end

      def budget_reminder_for(remaining)
        case remaining
        when ..0 then "[URGENT: This is your LAST step. Call final_answer NOW with your best answer.]"
        when 1   then "[WARNING: 1 step remaining - wrap up and call final_answer next step]"
        when 2   then "[Budget: 2 steps remaining - start wrapping up]"
        when 3..4 then "[Budget: #{remaining} steps remaining]"
        end
      end

      def calculate_remaining_steps(action_step)
        step_num = action_step.step_number || 0
        @max_steps - step_num - 1 # -1 because this step is done
      end
    end
  end
end
