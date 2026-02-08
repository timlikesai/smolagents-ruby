module Smolagents
  module Types
    # Immutable runtime statistics for an agent run.
    #
    # Tracks step counts, token usage, tool calls, model calls, errors, and timing.
    # Accumulates via immutable `record_*` methods that return new instances.
    #
    # @example Creating empty stats
    #   stats = AgentStats.zero
    #   stats.steps_taken  # => 0
    #
    # @example Recording a step
    #   stats = AgentStats.zero.record_step
    #   stats.steps_taken  # => 1
    #
    # @example Recording a model call
    #   stats = AgentStats.zero.record_model_call(tokens: 150, duration_ms: 350)
    #   stats.total_tokens  # => 150
    #
    # @see Concerns::Agents::StatsTracking For the concern that accumulates stats
    AgentStats = Data.define(
      :steps_taken, :total_tokens, :prompt_tokens, :completion_tokens,
      :tool_calls, :tool_errors, :model_calls, :duration_ms, :errors
    ) do
      # Creates stats with all counters at zero.
      #
      # @return [AgentStats]
      # @example
      #   stats = AgentStats.zero
      def self.zero
        new(
          steps_taken: 0, total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
          tool_calls: 0, tool_errors: 0, model_calls: 0, duration_ms: 0, errors: 0
        )
      end

      # Record a completed step.
      #
      # @return [AgentStats] New stats with step counted
      # @example
      #   stats = AgentStats.zero.record_step
      def record_step = with(steps_taken: steps_taken + 1)

      # Record a model generation call.
      #
      # @param tokens [Integer] Total tokens used
      # @param prompt [Integer] Prompt tokens (default 0)
      # @param completion [Integer] Completion tokens (default 0)
      # @param duration_ms [Integer] Call duration in milliseconds (default 0)
      # @return [AgentStats] New stats with model call counted
      # @example
      #   stats = AgentStats.zero.record_model_call(tokens: 150, duration_ms: 350)
      def record_model_call(tokens: 0, prompt: 0, completion: 0, duration_ms: 0)
        with(
          total_tokens: total_tokens + tokens,
          prompt_tokens: prompt_tokens + prompt,
          completion_tokens: completion_tokens + completion,
          model_calls: model_calls + 1,
          duration_ms: self.duration_ms + duration_ms
        )
      end

      # Record a tool call.
      #
      # @param error [Boolean] Whether the call errored
      # @return [AgentStats] New stats with tool call counted
      # @example
      #   stats = AgentStats.zero.record_tool_call(error: false)
      def record_tool_call(error: false)
        with(
          tool_calls: tool_calls + 1,
          tool_errors: tool_errors + (error ? 1 : 0)
        )
      end

      # Record an error.
      #
      # @return [AgentStats] New stats with error counted
      # @example
      #   stats = AgentStats.zero.record_error
      def record_error = with(errors: errors + 1)

      # Average tokens per model call.
      #
      # @return [Float]
      # @example
      #   stats.avg_tokens_per_call  # => 166.7
      def avg_tokens_per_call = model_calls.positive? ? total_tokens.to_f / model_calls : 0.0

      # Average duration per model call in milliseconds.
      #
      # @return [Float]
      # @example
      #   stats.avg_model_duration_ms  # => 500.0
      def avg_model_duration_ms = model_calls.positive? ? duration_ms.to_f / model_calls : 0.0

      # Tool error rate.
      #
      # @return [Float] Fraction 0.0-1.0
      # @example
      #   stats.tool_error_rate  # => 0.2
      def tool_error_rate = tool_calls.positive? ? tool_errors.to_f / tool_calls : 0.0

      # Whether any activity has occurred.
      #
      # @return [Boolean]
      # @example
      #   AgentStats.zero.empty?  # => true
      def empty? = steps_taken.zero? && model_calls.zero? && tool_calls.zero?

      # Serializable hash representation.
      #
      # @return [Hash]
      # @example
      #   stats.to_h  # => { steps_taken: 3, total_tokens: 500, ... }
      def to_h
        {
          steps_taken:, total_tokens:, prompt_tokens:, completion_tokens:,
          tool_calls:, tool_errors:, model_calls:, duration_ms:, errors:,
          avg_tokens_per_call: avg_tokens_per_call.round(1),
          avg_model_duration_ms: avg_model_duration_ms.round(1),
          tool_error_rate: tool_error_rate.round(3)
        }
      end
    end
  end
end
