# Custom RSpec formatter that only outputs failures
# No dots, no test names during run - just failures and summary at end
class FailuresOnlyFormatter
  RSpec::Core::Formatters.register self, :example_finished, :dump_failures, :dump_pending, :dump_summary

  def initialize(output)
    @output = output
    @example_times = []
  end

  def example_finished(notification)
    example = notification.example
    @example_times << {
      description: example.full_description,
      location: example.location,
      time: example.execution_result.run_time
    }
  end

  def dump_failures(notification)
    return if notification.failure_notifications.empty?

    @output.puts "\nFailures:\n"
    notification.failure_notifications.each_with_index do |failure, index|
      @output.puts "\n  #{index + 1}) #{failure.description}"
      @output.puts "     #{failure.exception.class}: #{failure.exception.message}"
      @output.puts "     # #{failure.example.location}"
      failure.exception.backtrace&.first(5)&.each do |line|
        @output.puts "     # #{line}"
      end
    end
  end

  def dump_pending(notification)
    return if notification.pending_notifications.empty?

    @output.puts "\nPending: (#{notification.pending_notifications.size} examples)"
  end

  def dump_summary(summary)
    @output.puts "\n#{"=" * 60}"
    @output.puts "Tests:   #{summary.example_count}"
    @output.puts "Passed:  #{summary.example_count - summary.failure_count - summary.pending_count}"
    @output.puts "Failed:  #{summary.failure_count}"
    @output.puts "Pending: #{summary.pending_count}"
    @output.puts "Time:    #{summary.formatted_duration}"
    @output.puts "=" * 60

    dump_slowest_examples

    return if summary.failed_examples.empty?

    @output.puts "\nFailed examples:"
    summary.failed_examples.each do |example|
      @output.puts "  rspec #{example.location}"
    end
  end

  private

  def dump_slowest_examples
    slowest = @example_times.sort_by { |e| -e[:time] }.first(10)
    return if slowest.empty?

    @output.puts "\nTop 10 slowest tests:"
    slowest.each do |example|
      time_ms = (example[:time] * 1000).round(1)
      @output.puts "  #{time_ms}ms  #{example[:location]}"
    end
  end
end
