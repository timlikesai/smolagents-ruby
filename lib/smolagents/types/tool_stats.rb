module Smolagents
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

    def merge(other)
      raise ArgumentError, "Cannot merge stats for different tools" unless name == other.name

      self.class.new(
        name: name,
        call_count: call_count + other.call_count,
        error_count: error_count + other.error_count,
        total_duration: total_duration + other.total_duration
      )
    end
  end

  class ToolStatsAggregator
    def initialize = @stats = {}

    def record(tool_name, duration:, error: false)
      @stats[tool_name] ||= { calls: 0, errors: 0, duration: 0.0 }
      @stats[tool_name][:calls] += 1
      @stats[tool_name][:errors] += 1 if error
      @stats[tool_name][:duration] += duration
    end

    def [](tool_name) = to_stats[tool_name]
    def tools = @stats.keys

    def to_stats
      @stats.transform_values do |data|
        ToolStats.new(
          name: data[:name] || @stats.key(data),
          call_count: data[:calls],
          error_count: data[:errors],
          total_duration: data[:duration]
        )
      end.tap { |hash| hash.each { |key, stats| hash[key] = stats.with(name: key) } }
    end

    def to_a = to_stats.values
    def to_h = to_stats.transform_values(&:to_h)

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
