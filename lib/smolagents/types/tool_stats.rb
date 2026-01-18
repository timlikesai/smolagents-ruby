module Smolagents
  module Types
    # Immutable statistics for a single tool's execution.
    #
    # Tracks call counts, error counts, and timing for a tool, providing
    # derived metrics like error rate and average duration. Supports recording
    # individual calls and merging statistics.
    #
    # @example Recording tool usage
    #   stats = Types::ToolStats.empty("search")
    #   stats = stats.record(duration: 0.5, error: false)
    #   stats = stats.record(duration: 0.3, error: false)
    #   stats.call_count  # => 2
    #   stats.avg_duration  # => 0.4
    #   stats.error_rate  # => 0.0
    #
    # @example Merging statistics
    #   merged = stats1.merge(stats2)  # Combines calls and timing
    #   merged.total_duration  # => stats1 + stats2 totals
    #
    # @see ToolStatsAggregator For aggregating stats across tools
    # @see RunResult#tool_stats For per-run statistics
    ToolStats = Data.define(:name, :call_count, :error_count, :total_duration) do
      # Calculates average duration per call.
      #
      # @return [Float] Average duration in seconds (0.0 if no calls)
      # @example
      #   stats.avg_duration  # => 0.45
      def avg_duration = call_count.positive? ? total_duration / call_count : 0.0

      # Calculates error rate as a fraction.
      #
      # @return [Float] Fraction of calls that errored (0.0-1.0, 0.0 if no calls)
      # @example
      #   stats.error_rate  # => 0.25
      def error_rate = call_count.positive? ? error_count.to_f / call_count : 0.0

      # Calculates number of successful calls.
      #
      # @return [Integer] Calls minus errors
      # @example
      #   stats.success_count  # => 8
      def success_count = call_count - error_count

      # Calculates success rate as a fraction.
      #
      # @return [Float] Fraction of calls that succeeded (0.0-1.0, 0.0 if no calls)
      # @example
      #   stats.success_rate  # => 0.8
      def success_rate = call_count.positive? ? success_count.to_f / call_count : 0.0

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with all fields including derived metrics
      # @example
      #   stats.to_h  # => { name: "search", call_count: 2, error_count: 0, ..., error_rate: 0.0 }
      def to_h
        {
          name:,
          call_count:,
          error_count:,
          success_count:,
          total_duration:,
          avg_duration:,
          error_rate:,
          success_rate:
        }
      end

      # Creates a ToolStats with zero values.
      #
      # @param name [String] Tool name
      # @return [ToolStats] Stats with all counters at zero
      # @example
      #   stats = ToolStats.empty("search")
      def self.empty(name) = new(name:, call_count: 0, error_count: 0, total_duration: 0.0)

      # Records a single tool execution.
      #
      # Increments call count and error count (if error), and adds duration
      # to total. Returns a new immutable ToolStats.
      #
      # @param duration [Float] Execution time in seconds
      # @param error [Boolean] Whether this call errored (default false)
      # @return [ToolStats] New stats with call recorded
      # @example
      #   stats = stats.record(duration: 0.5, error: false)
      #   stats = stats.record(duration: 0.1, error: true)  # Error
      def record(duration:, error: false)
        with(
          call_count: call_count + 1,
          error_count: error_count + (error ? 1 : 0),
          total_duration: total_duration + duration
        )
      end

      # Merges stats from another tool with the same name.
      #
      # Combines call counts, error counts, and total durations.
      # Useful for aggregating stats across multiple runs.
      #
      # @param other [ToolStats] Stats to merge (must have same name)
      # @return [ToolStats] New merged stats
      # @raise [ArgumentError] If tools have different names
      # @example
      #   merged = stats1.merge(stats2)
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
