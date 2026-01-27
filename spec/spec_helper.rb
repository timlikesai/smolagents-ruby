# Bootsnap caches compiled Ruby bytecode for faster subsequent loads
require "bootsnap"
Bootsnap.setup(
  cache_dir: "tmp/cache",
  compile_cache_iseq: true,   # Compile Ruby bytecode
  compile_cache_yaml: true    # Compile YAML files
)

# SimpleCov must be loaded first, before any application code
require "simplecov"

# For parallel_tests: unique command name per process enables proper merging
# See: https://github.com/simplecov-ruby/simplecov#merging-test-runs-under-different-execution-environments
SimpleCov.command_name "rspec#{ENV.fetch("TEST_ENV_NUMBER", "")}"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/examples/"

  # Testing module requires live models - coverage via integration tests
  add_filter "lib/smolagents/testing/"
  add_filter "lib/smolagents/testing.rb"

  add_group "Agents", "lib/smolagents/agents"
  add_group "Builders", "lib/smolagents/builders"
  add_group "Concerns", "lib/smolagents/concerns"
  add_group "Events", "lib/smolagents/events"
  add_group "Executors", "lib/smolagents/executors"
  add_group "Models", "lib/smolagents/models"
  add_group "Persistence", "lib/smolagents/persistence"
  add_group "Telemetry", "lib/smolagents/telemetry"
  add_group "Tools", "lib/smolagents/tools"
  add_group "Types", "lib/smolagents/types"

  minimum_coverage 80
  minimum_coverage_by_file 30 # Some files require integration/live tests

  # Suppress per-process output in parallel runs - only final merged report matters
  if ENV["TEST_ENV_NUMBER"]
    formatter SimpleCov::Formatter::SimpleFormatter
  end
end

require "logger"
require "faraday"
require "resolv"
require "smolagents"
require "stoplight"
require "timecop"
require "webmock/rspec"

# Skip retry delays in tests - retries still execute, just without sleeping.
# This shaves ~3.5s off the test suite (retry backoff waits).
module NoRetryDelay
  def retry_delay(_seconds) = nil
end
Smolagents::Concerns::Retryable.prepend(NoRetryDelay)
Smolagents::Concerns::RetryExecution.prepend(NoRetryDelay)

# Disable all network connections in unit tests
# Integration tests (tagged :integration) can re-enable as needed
WebMock.disable_net_connect!

# Stub localhost:1234 (LM Studio default) to prevent connection attempts during load
WebMock.stub_request(:any, /localhost:1234/).to_return(status: 200, body: '{"data":[]}')

# Suppress thread exception noise in test output
# Exceptions are still raised and handled; this just prevents stderr spam
Thread.report_on_exception = false

# Suppress Ractor experimental API warning
# We're aware it's experimental; no need to see this on every test run
Warning[:experimental] = false

# Load support files - includes NetworkStubs for DNS mocking
# See spec/support/network_stubs.rb for documentation on network testing patterns
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

class FailingStoplightNotifier < Stoplight::Notifier::Base
  def notify(light, from_color, to_color, error)
    raise "Unexpected circuit breaker state change: #{light.name} #{from_color} -> #{to_color} (#{error&.message}). " \
          "If this is intentional, set Stoplight.default_notifiers = [] in a before block."
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  # Tag semantics:
  #   :integration - Tests that exercise full agent/executor flows or require external services.
  #                  Excluded by default; run with: bundle exec rspec --tag integration
  #   :slow        - Unit tests that legitimately need more time (threading, sleeps, etc).
  #                  Allows 100ms instead of default 20ms timing limit.
  config.filter_run_excluding :integration

  # Include testing helpers, matchers, and factories globally
  config.include Smolagents::Testing::Helpers
  config.include Smolagents::Testing::Matchers
  config.include TestFixtures

  # Timing enforcement: Tests should be lightning fast for instant feedback.
  # Default: 80ms per test (400ms in CI). Override with metadata:
  #   it "spawns ractor", :slow do ... end           # allows 200ms (1s in CI)
  #   it "custom limit", max_time: 0.05 do ... end   # allows 50ms
  #
  # IMPORTANT: Timing failures are real failures. Do NOT:
  #   - Run the test multiple times hoping it passes
  #   - Increase the timeout without understanding why
  #   - Mark as :slow without profiling first
  # Instead: Profile the code, find the bottleneck, fix it.
  ci_multiplier = ENV["CI"] ? 5 : 1
  config.add_setting :max_example_time, default: 0.08 * ci_multiplier
  config.add_setting :max_suite_time, default: 20.0 * ci_multiplier

  suite_time = 0.0
  slow_tag_time = 0.2 * ci_multiplier
  config.around do |example|
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    example.run
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    suite_time += elapsed

    # Determine max time: explicit max_time > :slow tag > default
    max_time = example.metadata[:max_time] || (example.metadata[:slow] ? slow_tag_time : config.max_example_time)
    next unless elapsed > max_time

    location = example.metadata[:location]
    raise <<~ERROR
      TIMING FAILURE: #{(elapsed * 1000).round}ms exceeds #{(max_time * 1000).round}ms limit
      Test: #{example.description}
      Location: #{location}

      This is a real failure. The code under test is too slow.
      Profile the test, find the bottleneck, and fix the underlying code.
      Do NOT increase timeouts or mark as :slow without understanding why.
    ERROR
  end
  config.after(:suite) { raise "Suite too slow (#{suite_time.round(1)}s)" if suite_time > config.max_suite_time }

  config.before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = [FailingStoplightNotifier.new]
  end

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Suppress false positive warnings for raise_error matcher
  RSpec::Expectations.configuration.on_potential_false_positives = :nothing

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
