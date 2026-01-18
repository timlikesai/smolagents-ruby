module Smolagents
  module Concerns
    # Injects structured step context into model prompts.
    #
    # Provides the model with critical decision-making information:
    # - Step budget (remaining steps)
    # - Last tool outcome (success/failure, duration)
    # - Plan progress (if planning enabled)
    #
    # This structured context helps the model make informed decisions
    # about when to wrap up, which tools to use, and how to proceed.
    #
    # @example Context injected before user message
    #   [CONTEXT]
    #   Step: 3 of 10 (7 remaining)
    #   Last: searxng_search ✓ 1.2s
    #   Plan: Step 2 of 4 - "Search for news"
    #
    module StepContext
      # Fallback for when Planning concern is not included.
      def inject_plan_into_messages(messages) = messages

      private

      # Injects step context into messages before code generation.
      # Wraps the plan injection to add additional context.
      #
      # @param messages [Array<ChatMessage>] Original messages
      # @return [Array<ChatMessage>] Messages with context injected
      def inject_context_into_messages(messages)
        context = build_step_context
        return messages unless context

        inject_before_last_user(messages, ChatMessage.system(context))
      end

      # Builds the structured step context string.
      #
      # @return [String, nil] Context string or nil if no context needed
      def build_step_context
        parts = []
        parts << step_budget_context
        parts << last_tool_context
        parts << plan_progress_context if respond_to?(:plan_progress_summary, true)
        parts.compact!
        return nil if parts.empty?

        "[CONTEXT]\n#{parts.join("\n")}"
      end

      # Step budget: "Step: 3 of 10 (7 remaining)"
      def step_budget_context
        return nil unless @max_steps && @ctx

        current = @ctx.step_number + 1
        remaining = @max_steps - current
        "Step: #{current} of #{@max_steps} (#{remaining} remaining)"
      end

      # Last tool outcome: "Last: searxng_search ✓ 1.2s"
      def last_tool_context
        return nil unless @executor.respond_to?(:tool_calls)

        calls = @executor.tool_calls
        return nil if calls.empty?

        last = calls.last
        status = last.success? ? "✓" : "✗"
        duration = format("%.1fs", last.duration)
        "Last: #{last.tool_name} #{status} #{duration}"
      end

      # Plan progress: "Plan: Step 2 of 4 - \"Search for news\""
      # Only included if planning is enabled and plan_progress_summary is available.
      def plan_progress_context
        return nil unless respond_to?(:plan_progress_summary, true)

        plan_progress_summary
      end

      # Injects a message before the last user message.
      #
      # @param messages [Array<ChatMessage>] Original messages
      # @param context_msg [ChatMessage] Message to inject
      # @return [Array<ChatMessage>] Messages with context injected
      def inject_before_last_user(messages, context_msg)
        last_user_idx = messages.rindex { |m| m.role == :user }
        return messages + [context_msg] unless last_user_idx

        messages.dup.insert(last_user_idx, context_msg)
      end
    end
  end
end
