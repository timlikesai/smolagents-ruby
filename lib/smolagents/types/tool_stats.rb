module Smolagents
  module Types
    # Immutable statistics for a single tool's execution.
    #
    # ToolStats tracks call counts, error counts, and timing for a tool,
    # providing derived metrics like error rate and average duration.
    #
    # @example Recording tool usage
    #   stats = Types::ToolStats.empty("search")
    #   stats = stats.record(duration: 0.5, error: false)
    #   stats.call_count  # => 1
    #   stats.avg_duration  # => 0.5
    #
    # @see ToolStatsAggregator For aggregating stats across tools
    ToolStats = Data.define(:name, :call_count, :error_count, :total_duration) do
      def avg_duration = call_count.positive? ? total_duration / call_count : 0.0
      def error_rate = call_count.positive? ? error_count.to_f / call_count : 0.0
      def success_count = call_count - error_count
      def success_rate = call_count.positive? ? success_count.to_f / call_count : 0.0

      def to_h
        {
          name: name,
          call_count: call_count,
          error_count: error_count,
          success_count: success_count,
          total_duration: total_duration,
          avg_duration: avg_duration,
          error_rate: error_rate,
          success_rate: success_rate
        }
      end

      def self.empty(name) = new(name: name, call_count: 0, error_count: 0, total_duration: 0.0)

      def record(duration:, error: false)
        with(
          call_count: call_count + 1,
          error_count: error_count + (error ? 1 : 0),
          total_duration: total_duration + duration
        )
      end

      def merge(other)
        raise ArgumentError, "Cannot merge stats for different tools" unless name == other.name

        with(
          call_count: call_count + other.call_count,
          error_count: error_count + other.error_count,
          total_duration: total_duration + other.total_duration
        )
      end
    end

    # Aggregates tool statistics across multiple tool calls.
    #
    # @example Tracking multiple tool executions
    #   aggregator = Types::ToolStatsAggregator.new
    #   aggregator.record("search", duration: 0.5, error: false)
    #   aggregator.record("search", duration: 0.3, error: false)
    #   aggregator["search"].call_count  # => 2
    #
    # @see ToolStats For individual tool statistics
    class ToolStatsAggregator
      def initialize = @stats = {}

      def record(tool_name, duration:, error: false)
        @stats[tool_name] = (@stats[tool_name] || ToolStats.empty(tool_name)).record(duration:, error:)
      end

      def [](tool_name) = @stats[tool_name]
      def tools = @stats.keys
      def to_a = @stats.values
      def to_h = @stats.transform_values(&:to_h)

      def self.from_steps(steps)
        aggregator = new
        steps.each do |step|
          next unless step.respond_to?(:tool_calls) && step.tool_calls

          duration = step.timing&.duration || 0.0
          per_tool_duration = step.tool_calls.size.positive? ? duration / step.tool_calls.size : 0.0

          has_error = !step.error.nil?
          step.tool_calls.each do |tc|
            aggregator.record(tc.name, duration: per_tool_duration, error: has_error)
          end
        end
        aggregator
      end
    end
  end
end
