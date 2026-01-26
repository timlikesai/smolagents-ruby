module Smolagents
  module Concerns
    # Builds structured step context for Context Orchestration.
    #
    # Provides the model with critical decision-making information:
    # - Step budget (remaining steps)
    # - Last tool outcome (success/failure, duration)
    # - Plan progress (if planning enabled)
    #
    # Used by Context::Providers.step_context to contribute to
    # the orchestrated context assembly at the TACTICAL layer.
    #
    # @example Context format
    #   [CONTEXT]
    #   Step: 3 of 10 (7 remaining)
    #   Last: searxng_search ✓ 1.2s
    #
    # @see Context::Providers.step_context
    # @see ContextOrchestration
    module StepContext
      private

      # Builds the structured step context string.
      # Called by Context::Providers.step_context via the orchestrator.
      #
      # @return [String, nil] Context string or nil if no context needed
      def build_step_context
        parts = [step_budget_context, last_tool_context].compact
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
    end
  end
end
