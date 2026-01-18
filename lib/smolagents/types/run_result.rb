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
      extend TypeSupport::FactoryBuilder
      include TypeSupport::Deconstructable
      include TypeSupport::StatePredicates

      # Factory methods for common states
      factory :success, state: :success, token_usage: nil, timing: nil
      factory :failure, state: :failure, token_usage: nil, timing: nil
      factory :error, state: :error, token_usage: nil, timing: nil
      factory :max_steps, state: :max_steps_reached, token_usage: nil, timing: nil

      # State predicates mapping
      state_predicates success: :success,
                       partial: :partial,
                       failure: :failure,
                       error: :error,
                       max_steps: :max_steps_reached,
                       timeout: :timeout,
                       terminal: Outcome::TERMINAL,
                       retriable: Outcome::RETRIABLE

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
