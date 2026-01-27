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
    duration = format("%.2f", summary.duration)
    # Output timing separately so parallel_tests can parse "X examples, Y failures" correctly
    @output.puts "#{summary.example_count} examples, #{summary.failure_count} failures"
    @output.puts "Worker #{@worker} done in #{duration}s"
  end
end
