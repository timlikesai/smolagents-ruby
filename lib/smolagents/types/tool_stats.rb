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
  end
end
