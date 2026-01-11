# frozen_string_literal: true

require "logger"
require "faraday"
require "smolagents"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

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
  end
end
