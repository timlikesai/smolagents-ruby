# frozen_string_literal: true

require "logger"
require "faraday"
require "retriable"
require "smolagents"
require "stoplight"
require "timecop"

# Make all sleeps instant during tests (except for those that explicitly need timing)
module FastSleep
  def sleep(duration = nil)
    # No-op for tests
  end
end

# Apply globally - tests that need real sleep can use Kernel.method(:sleep).call
Object.prepend(FastSleep)

class FailingStoplightNotifier < Stoplight::Notifier::Base
  def notify(light, from_color, to_color, error)
    raise "Unexpected circuit breaker state change: #{light.name} #{from_color} -> #{to_color} (#{error&.message}). " \
          "If this is intentional, set Stoplight.default_notifiers = [] in a before block."
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = [FailingStoplightNotifier.new]
  end

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter lines from backtrace
  config.filter_gems_from_backtrace "gem", "bundler"

  # Randomize spec order
  config.order = :random
  Kernel.srand config.seed

  # Reset Smolagents configuration after each example to prevent mock leakage
  config.after do
    Smolagents.reset_configuration!
    Timecop.return
  end

  # Fail if any test modifies frozen time and doesn't clean up
  config.around(:each, :freeze_time) do |example|
    example.run
  ensure
    Timecop.return
  end
end
