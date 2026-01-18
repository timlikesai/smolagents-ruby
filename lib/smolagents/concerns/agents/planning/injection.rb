module Smolagents
  module Concerns
    module Planning
      # Plan injection into action generation prompts.
      #
      # When planning is enabled, injects the current plan as a reminder
      # before each action generation. This helps the model stay on track.
      module Injection
        PLAN_REMINDER_TEMPLATE = <<~PROMPT.freeze
          CURRENT PLAN:
          %<plan>s

          Execute the next step in this plan. Each action should advance toward completing a planned step.
        PROMPT

        private

        # Builds a plan reminder message to inject into the conversation.
        #
        # @return [ChatMessage, nil] Plan reminder message or nil if no plan
        def build_plan_reminder_message
          return nil unless @planning_interval&.positive?
          return nil unless @plan_context&.initialized?
          return nil if @plan_context.plan.nil? || @plan_context.plan.empty?

          ChatMessage.system(format(PLAN_REMINDER_TEMPLATE, plan: @plan_context.plan))
        end

        # Injects plan context into messages for model generation.
        #
        # @param messages [Array<ChatMessage>] Original messages
        # @return [Array<ChatMessage>] Messages with plan injected
        def inject_plan_into_messages(messages)
          reminder = build_plan_reminder_message
          return messages unless reminder

          # Insert plan reminder before the last user message
          last_user_idx = messages.rindex { |m| m.role == :user }
          return messages + [reminder] unless last_user_idx

          messages.dup.insert(last_user_idx, reminder)
        end
      end
    end
  end
end
