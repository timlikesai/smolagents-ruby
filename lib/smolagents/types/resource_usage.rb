module Smolagents
  module Types
    # Immutable resource usage totals for an agent run.
    #
    # Tracks token consumption, timing, and call counts. Produced by the
    # StatsTracking concern as a summary of resource consumption.
    #
    # @example Creating empty usage
    #   usage = ResourceUsage.zero
    #   usage.total_tokens  # => 0
    #
    # @example Accumulating usage
    #   usage = ResourceUsage.zero
    #     .add_model_call(prompt_tokens: 100, completion_tokens: 50, duration_ms: 350)
    #     .add_tool_call(duration_ms: 20)
    #   usage.total_tokens  # => 150
    #
    # @see Concerns::Agents::StatsTracking For the concern that produces this
    ResourceUsage = Data.define(
      :total_tokens, :prompt_tokens, :completion_tokens,
      :total_duration_ms, :model_duration_ms, :tool_duration_ms,
      :api_calls, :tool_calls
    ) do
      # Creates usage with all counters at zero.
      # @return [ResourceUsage]
      def self.zero
        new(
          total_tokens: 0, prompt_tokens: 0, completion_tokens: 0,
          total_duration_ms: 0, model_duration_ms: 0, tool_duration_ms: 0,
          api_calls: 0, tool_calls: 0
        )
      end

      # Record a model API call.
      # @param prompt_tokens [Integer] Prompt tokens consumed
      # @param completion_tokens [Integer] Completion tokens generated
      # @param duration_ms [Integer] Call duration in milliseconds
      # @return [ResourceUsage] New usage with call recorded
      def add_model_call(prompt_tokens: 0, completion_tokens: 0, duration_ms: 0)
        tokens = prompt_tokens + completion_tokens
        with(
          total_tokens: total_tokens + tokens,
          prompt_tokens: self.prompt_tokens + prompt_tokens,
          completion_tokens: self.completion_tokens + completion_tokens,
          total_duration_ms: total_duration_ms + duration_ms,
          model_duration_ms: model_duration_ms + duration_ms,
          api_calls: api_calls + 1
        )
      end

      # Record a tool execution.
      # @param duration_ms [Integer] Execution duration in milliseconds
      # @return [ResourceUsage] New usage with call recorded
      def add_tool_call(duration_ms: 0)
        with(
          total_duration_ms: total_duration_ms + duration_ms,
          tool_duration_ms: tool_duration_ms + duration_ms,
          tool_calls: tool_calls + 1
        )
      end

      # Percentage of time spent in model calls.
      # @return [Float] 0.0-100.0
      def model_time_percent
        return 0.0 if total_duration_ms.zero?

        (model_duration_ms.to_f / total_duration_ms * 100).round(1)
      end

      # Percentage of time spent in tool calls.
      # @return [Float] 0.0-100.0
      def tool_time_percent
        return 0.0 if total_duration_ms.zero?

        (tool_duration_ms.to_f / total_duration_ms * 100).round(1)
      end

      # Whether any resources have been consumed.
      # @return [Boolean]
      def empty? = api_calls.zero? && tool_calls.zero?

      # Human-readable summary.
      # @return [String]
      def summary
        "#{total_tokens} tokens (#{api_calls} API calls, #{tool_calls} tool calls) in #{total_duration_ms}ms"
      end

      # Serializable hash representation.
      # @return [Hash]
      def to_h
        {
          total_tokens:, prompt_tokens:, completion_tokens:,
          total_duration_ms:, model_duration_ms:, tool_duration_ms:,
          api_calls:, tool_calls:,
          model_time_percent:, tool_time_percent:
        }
      end
    end
  end
end
