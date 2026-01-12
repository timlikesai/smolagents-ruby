require "logger"
require "faraday"
require "retriable"
require "smolagents"
require "stoplight"
require "timecop"

module FastSleep
  def sleep(duration = nil); end
end

Object.prepend(FastSleep)

class FailingStoplightNotifier < Stoplight::Notifier::Base
  def notify(light, from_color, to_color, error)
    raise "Unexpected circuit breaker state change: #{light.name} #{from_color} -> #{to_color} (#{error&.message}). " \
          "If this is intentional, set Stoplight.default_notifiers = [] in a before block."
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = [FailingStoplightNotifier.new]
  end

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.filter_gems_from_backtrace "gem", "bundler"

  config.order = :random
  Kernel.srand config.seed

  config.after do
    Smolagents.reset_configuration!
    Timecop.return
  end

  config.around(:each, :freeze_time) do |example|
    example.run
  ensure
    Timecop.return
  end
end
