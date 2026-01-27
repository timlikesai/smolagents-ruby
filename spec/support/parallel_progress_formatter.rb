# Minimal formatter for parallel test runs
# Silent during run, outputs count at end for parallel_tests to aggregate.
class ParallelProgressFormatter
  RSpec::Core::Formatters.register self, :example_failed, :dump_summary

  def initialize(output)
    @output = output
  end

  def example_failed(notification)
    @output.puts "\nFAIL: #{notification.example.location}"
    @output.puts "  #{notification.exception.class}: #{notification.exception.message}"
    notification.exception.backtrace&.first(3)&.each { |line| @output.puts "  #{line}" }
  end

  def dump_summary(summary)
    # parallel_tests parses "X examples, Y failures" to aggregate totals
    @output.puts "#{summary.example_count} examples, #{summary.failure_count} failures"
  end
end
