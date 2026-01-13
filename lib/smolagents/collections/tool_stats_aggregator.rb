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
      def initialize = @stats = {}

      def record(tool_name, duration:, error: false)
        @stats[tool_name] = (@stats[tool_name] || Types::ToolStats.empty(tool_name)).record(duration:, error:)
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
