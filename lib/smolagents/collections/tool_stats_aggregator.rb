module Smolagents
  module Collections
    # Aggregates tool statistics across multiple tool calls.
    #
    # ToolStatsAggregator tracks performance metrics for tools used by an agent.
    # Accumulates call counts, error counts, and timing statistics by tool name.
    # Useful for analyzing agent efficiency, identifying slow tools, and monitoring errors.
    #
    # @example Tracking multiple tool executions
    #   aggregator = ToolStatsAggregator.new
    #   aggregator.record("search", duration: 0.5, error: false)
    #   aggregator.record("search", duration: 0.3, error: false)
    #   aggregator["search"].call_count  # => 2
    #   aggregator["search"].total_duration  # => 0.8
    #
    # @example Analyzing tool performance
    #   stats = aggregator["search"]
    #   puts "Calls: #{stats.call_count}"
    #   puts "Errors: #{stats.error_count}"
    #   puts "Avg duration: #{stats.average_duration}s"
    #
    # @see Types::ToolStats For individual tool statistics
    # @see Collections::AgentMemory#action_steps Source of tool execution data
    class ToolStatsAggregator
      # Creates a new empty aggregator.
      #
      # Initializes an empty aggregator. Tools are added as they are recorded.
      #
      # @example Creating an aggregator
      #   aggregator = ToolStatsAggregator.new
      #   aggregator.record("search", duration: 1.0, error: false)
      #
      # @see #record Track a tool execution
      # @see #from_steps Create aggregator from agent steps
      def initialize = @stats = {}

      # Records a tool execution.
      #
      # Adds execution data for a tool to the aggregator. If the tool hasn't
      # been recorded before, creates initial statistics. Otherwise, updates
      # existing statistics with the new execution data.
      #
      # @param tool_name [String] Name of the tool (e.g., "search", "file_writer")
      # @param duration [Float] Execution time in seconds
      # @param error [Boolean] Whether the execution errored (default: false)
      #
      # @return [Types::ToolStats] Updated stats for the tool
      #
      # @example Recording tool executions
      #   aggregator = ToolStatsAggregator.new
      #   aggregator.record("search", duration: 0.5, error: false)
      #   aggregator.record("search", duration: 0.3, error: false)
      #   aggregator.record("file", duration: 1.2, error: false)
      #
      # @example Recording an error
      #   aggregator.record("api_call", duration: 0.1, error: true)
      #
      # @see #[](tool_name) Get stats for a tool
      # @see Types::ToolStats#record Underlying stats recording
      def record(tool_name, duration:, error: false)
        @stats[tool_name] = (@stats[tool_name] || Types::ToolStats.empty(tool_name)).record(duration:, error:)
      end

      # Returns stats for a specific tool.
      #
      # Looks up statistics for a single tool by name. Returns nil if the tool
      # has never been recorded.
      #
      # @param tool_name [String] Name of the tool
      #
      # @return [Types::ToolStats, nil] Stats for the tool, or nil if not recorded
      #
      # @example Getting tool stats
      #   stats = aggregator["search"]
      #   puts stats.call_count if stats
      #
      # @example Checking if tool was used
      #   if aggregator["search"]
      #     puts "Search was called"
      #   end
      #
      # @see #record Record a tool execution
      # @see #tools List all recorded tools
      def [](tool_name) = @stats[tool_name]

      # Returns names of all recorded tools.
      #
      # Lists tool names that have been recorded at least once.
      #
      # @return [Array<String>] Tool names (in insertion order)
      #
      # @example Listing tools
      #   aggregator.record("search", duration: 1.0)
      #   aggregator.record("file", duration: 0.5)
      #   aggregator.tools  # => ["search", "file"]
      #
      # @see #[](tool_name) Get stats for specific tool
      # @see #to_h Get all stats as hash
      def tools = @stats.keys

      # Returns all stats as an array.
      #
      # Converts all aggregated tool statistics to an array of ToolStats objects.
      #
      # @return [Array<Types::ToolStats>] All tool stats in insertion order
      #
      # @example Getting all stats
      #   aggregator.to_a.each do |stats|
      #     puts "#{stats.name}: #{stats.call_count} calls"
      #   end
      #
      # @see #to_h Get stats as hash
      # @see Types::ToolStats Individual tool statistics
      def to_a = @stats.values

      # Returns all stats as a hash.
      #
      # Converts all aggregated statistics to a hash mapping tool names to
      # their stats as hashes. Useful for serialization or detailed inspection.
      #
      # @return [Hash<String, Hash>] Tool name to stats hash mapping
      #
      # @example Getting all stats as hash
      #   stats_hash = aggregator.to_h
      #   stats_hash["search"]  # => { name: "search", call_count: 2, ... }
      #
      # @see #to_a Get stats as array
      # @see Types::ToolStats#to_h Individual stat hash format
      def to_h = @stats.transform_values(&:to_h)

      # Creates an aggregator from action steps.
      #
      # Builds an aggregator by analyzing ActionStep instances from agent
      # execution. Distributes step duration across all tools called in that step.
      # Marks executions as errored if the step had any error.
      #
      # @param steps [Array<Types::ActionStep>] Steps to aggregate (typically from AgentMemory)
      #
      # @return [ToolStatsAggregator] Aggregator with stats extracted from steps
      #
      # @example Creating from agent memory
      #   memory = agent.memory
      #   stats = ToolStatsAggregator.from_steps(memory.action_steps.to_a)
      #   puts stats["search"].call_count
      #
      # @example Analyzing agent execution
      #   result = agent.run("Find information")
      #   stats = ToolStatsAggregator.from_steps(result.step_history)
      #   stats.tools.each { |name| puts "#{name}: #{stats[name].call_count} calls" }
      #
      # @see Collections::AgentMemory#action_steps Source of step data
      # @see Types::ActionStep#tool_calls Tools called in a step
      # @see Types::ActionStep#timing Execution timing
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
