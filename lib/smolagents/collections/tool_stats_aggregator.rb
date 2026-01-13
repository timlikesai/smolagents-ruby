module Smolagents
  module Collections
    # Aggregates tool statistics across multiple tool calls.
    #
    # @example Tracking multiple tool executions
    #   aggregator = ToolStatsAggregator.new
    #   aggregator.record("search", duration: 0.5, error: false)
    #   aggregator.record("search", duration: 0.3, error: false)
    #   aggregator["search"].call_count  # => 2
    #
    # @see Types::ToolStats For individual tool statistics
    class ToolStatsAggregator
      # Creates a new empty aggregator.
      def initialize = @stats = {}

      # Records a tool execution.
      #
      # @param tool_name [String] Name of the tool
      # @param duration [Float] Execution time in seconds
      # @param error [Boolean] Whether the execution errored
      # @return [Types::ToolStats] Updated stats for the tool
      def record(tool_name, duration:, error: false)
        @stats[tool_name] = (@stats[tool_name] || Types::ToolStats.empty(tool_name)).record(duration:, error:)
      end

      # Returns stats for a specific tool.
      #
      # @param tool_name [String] Name of the tool
      # @return [Types::ToolStats, nil] Stats for the tool, or nil if not recorded
      def [](tool_name) = @stats[tool_name]

      # Returns names of all recorded tools.
      #
      # @return [Array<String>] Tool names
      def tools = @stats.keys

      # Returns all stats as an array.
      #
      # @return [Array<Types::ToolStats>] All tool stats
      def to_a = @stats.values

      # Returns all stats as a hash.
      #
      # @return [Hash] Tool name to stats hash mapping
      def to_h = @stats.transform_values(&:to_h)

      # Creates an aggregator from action steps.
      #
      # @param steps [Array<Types::ActionStep>] Steps to aggregate
      # @return [ToolStatsAggregator] Aggregator with stats from steps
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
