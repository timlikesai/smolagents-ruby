module Smolagents
  module Concerns
    # Budget tracking for code execution steps and context usage.
    #
    # Provides both step budget and context/token awareness signals to help
    # models understand when they need to wrap up and provide a final answer.
    #
    # == Step Budget Signals
    # Progressive urgency based on remaining steps (gentle at 4, urgent at 1).
    #
    # == Context Signals
    # Token usage percentage warnings when a budget is configured on memory.
    # Helps prevent context overflow by prompting summarization.
    #
    # @see CodeExecution For the main execution flow
    # @see Runtime::Memory::TokenEstimation For token tracking
    module BudgetTracking
      private

      # Appends budget and context signals to observations.
      # Combines step budget reminders with token usage warnings.
      def with_budget_reminder(action_step, logs)
        signals = collect_signals(action_step)
        signals.empty? ? logs : "#{logs}\n#{signals.join("\n")}"
      end

      def collect_signals(action_step)
        [step_budget_signal(action_step), context_signal].compact
      end

      # Step budget signal based on remaining steps.
      def step_budget_signal(action_step)
        return nil unless @max_steps

        remaining = calculate_remaining_steps(action_step)
        budget_reminder_for(remaining)
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

      # Context signal based on token usage percentage.
      # Returns nil if no budget configured or usage is below warning threshold.
      def context_signal
        return nil unless @memory.respond_to?(:token_usage_percent)

        usage = @memory.token_usage_percent
        return nil unless usage

        context_signal_for(usage)
      end

      def context_signal_for(usage)
        case usage
        when 0.9.. then "[URGENT: Context 90%+ full. Summarize findings and call final_answer NOW.]"
        when 0.75...0.9 then "[Context at #{(usage * 100).round}%. Consider summarizing soon.]"
        when 0.6...0.75 then "[Context at #{(usage * 100).round}%]"
        end
      end
    end
  end
end
