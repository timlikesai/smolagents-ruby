module Smolagents
  module Types
    # Immutable result from running an agent task.
    #
    # Contains final output, outcome state, steps, token usage, and timing.
    #
    # @!attribute [r] output [Object] Final output from the agent
    # @!attribute [r] state [Symbol] Outcome state (:success, :failure, :error, etc.)
    # @!attribute [r] steps [Array] All steps taken during execution
    # @!attribute [r] token_usage [TokenUsage, nil] Token usage statistics
    # @!attribute [r] timing [Timing, nil] Execution timing
    RunResult = Data.define(:output, :state, :steps, :token_usage, :timing) do
      # State predicates - delegate to Outcome module
      def success? = Outcome.success?(state)
      def partial? = Outcome.partial?(state)
      def failure? = Outcome.failure?(state)
      def error? = Outcome.error?(state)
      def max_steps? = Outcome.max_steps?(state)
      def timeout? = Outcome.timeout?(state)
      def terminal? = Outcome.terminal?(state)
      def retriable? = Outcome.retriable?(state)

      # Alias for outcome state
      def outcome = state

      # @return [ToolStatsAggregator] Statistics by tool name
      def tool_stats = ToolStatsAggregator.from_steps(steps)

      # @return [Float, nil] Seconds elapsed, or nil if timing not captured
      def duration = timing&.duration

      # @return [Integer] Count of ActionStep instances
      def step_count = action_steps.count

      # @return [Array<ActionStep>] Only action steps from the run
      def action_steps = steps.select { |s| s.is_a?(ActionStep) }

      # @return [Array<Hash>] Hashes with :step, :duration, :has_error, :is_final
      def step_timings
        action_steps.map do |step|
          { step: step.step_number, duration: step.timing&.duration&.round(3),
            has_error: !step.error.nil?, is_final: step.is_final_answer }
        end
      end

      # Human-readable summary of the entire run.
      def summary
        [
          "Run #{state}: #{step_count} steps in #{duration&.round(2)}s",
          output && "Output: #{truncate_output(output)}",
          token_usage && format_tokens(token_usage),
          "Steps:", *step_timings.map { format_step_timing(it) }
        ].compact.join("\n")
      end

      def to_h = { output:, state:, steps:, token_usage: token_usage&.to_h, timing: timing&.to_h }
      def deconstruct_keys(_keys) = { output:, state:, steps:, token_usage:, timing: }

      private

      def format_step_timing(timing)
        status = if timing[:is_final]
                   " [FINAL]"
                 else
                   (timing[:has_error] ? " [ERROR]" : "")
                 end
        "  #{timing[:step]}: #{timing[:duration]}s#{status}"
      end

      def format_tokens(usage)
        "Tokens: #{usage.total_tokens} (#{usage.input_tokens} in, #{usage.output_tokens} out)"
      end

      def truncate_output(out)
        str = out.to_s
        str.length > 100 ? "#{str.slice(0, 100)}..." : str
      end
    end
  end
end
