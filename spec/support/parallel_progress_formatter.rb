# Minimal formatter for parallel test runs
# Shows worker start/complete to make parallel execution visible.
class ParallelProgressFormatter
  RSpec::Core::Formatters.register self, :start, :example_failed, :dump_summary

  def initialize(output)
    @output = output
    @output.sync = true # Flush immediately to show parallel execution
    @worker = ENV.fetch("TEST_ENV_NUMBER", "1")
    @worker = "1" if @worker.empty?
  end

  def start(notification)
    @output.puts "Worker #{@worker} starting: #{notification.count} examples"
  end

  def example_failed(notification)
    @output.puts "\nFAIL: #{notification.example.location}"
    @output.puts "  #{notification.exception.class}: #{notification.exception.message}"
    notification.exception.backtrace&.first(3)&.each { |line| @output.puts "  #{line}" }
  end

  def dump_summary(summary)
    # parallel_tests parses "X examples, Y failures" to aggregate - keep on own line
    @output.puts "#{summary.example_count} examples, #{summary.failure_count} failures [worker #{@worker}]"
  end
end
