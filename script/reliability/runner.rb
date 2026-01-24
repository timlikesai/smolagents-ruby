require "timeout"
require "json"
require "fileutils"
require "stoplight"

require_relative "test_definitions"
require_relative "logging"
require_relative "dry_run_model"

module Reliability
  # Runs reliability tests with proper isolation and logging
  class Runner
    TestResult = Data.define(:name, :passed, :steps, :duration, :output, :error)

    attr_reader :server, :log_dir, :logger, :dry_run

    def initialize(server: nil, log_dir: "logs/reliability", logger: nil, dry_run: false, verbose: false)
      @server = server
      @log_dir = log_dir
      @logger = logger
      @dry_run = dry_run
      @verbose = verbose
      @backoff_until = nil
      @dry_run_model = DryRunModel.new(verbose:) if dry_run
      FileUtils.mkdir_p(log_dir)
    end

    # Reset all circuit breakers to allow fresh testing
    def reset_circuits!
      data_store = Stoplight.default_data_store
      data_store.names.each do |name|
        light = Stoplight(name)
        data_store.clear_failures(light)
        data_store.clear_state(light)
      end
    rescue StandardError
      # Ignore circuit reset errors
    end

    # Ensure model is loaded before testing
    def warmup_model(model_id, timeout: 120)
      status = @server.model_status(model_id)
      return true if status&.ready?

      puts "  Warming up #{model_id}..."
      @server.warmup(model_id, timeout:)
      sleep 2 # rubocop:disable Smolagents/NoSleep -- Brief pause after warmup is intentional
      true
    rescue StandardError => e
      puts "  Warmup failed: #{e.message}"
      false
    end

    # Check if we're in backoff period
    def in_backoff? = @backoff_until && Time.now < @backoff_until

    # Enter backoff mode after server error
    def enter_backoff!(seconds: 10)
      @backoff_until = Time.now + seconds
      puts "  [!] Server error - backing off for #{seconds}s..."
      reset_circuits!
      sleep seconds # rubocop:disable Smolagents/NoSleep -- Backoff sleep is intentional
      @backoff_until = nil
    end

    # Check if any circuit is open (red)
    def circuit_open?
      data_store = Stoplight.default_data_store
      data_store.names.any? do |name|
        light = Stoplight(name)
        light.color == Stoplight::Color::RED
      end
    rescue StandardError
      false
    end

    # Run a single test with a fresh agent
    def run_test(model_id, test, timeout: 60, retries: 1)
      @test_start = Time.now
      @logger&.test_start(test[:name], test[:task])
      execute_test(build_agent(prepare_model(model_id, test), test), test, timeout)
    rescue Timeout::Error then handle_timeout_error(test, timeout)
    rescue Faraday::ServerError, Faraday::ConnectionFailed => e
      handle_server_error(e, model_id, test, timeout, retries)
    rescue Smolagents::AgentGenerationError => e
      handle_circuit_error(e, model_id, test, timeout, retries)
    rescue StandardError => e then handle_standard_error(e, test)
    end

    # Run all tests for a level
    def run_level(model_id, level, timeout: 60)
      tests = TestDefinitions.for_level(level)
      tests.map { |test| run_test(model_id, test, timeout:) }
    end

    # Run multiple levels
    def run_levels(model_id, levels: 1..7, timeout: 60, stop_on_failure: false)
      results = {}
      levels.each do |level|
        next unless TestDefinitions::ALL_LEVELS.key?(level)

        level_results = run_level(model_id, level, timeout:)
        results[level] = level_results
        break if stop_on_failure && level_results.any? { |r| !r.passed }
      end
      results
    end

    # Summary of results
    def summarize(results)
      total_passed = 0
      total_tests = 0

      results.each_value do |level_results|
        total_passed += level_results.count(&:passed)
        total_tests += level_results.size
      end

      { passed: total_passed, total: total_tests,
        rate: total_tests.positive? ? (total_passed.to_f / total_tests * 100).round(1) : 0 }
    end

    private

    def prepare_model(model_id, test)
      if @dry_run
        puts "  [DRY RUN] #{test[:name]}" if @verbose
        @dry_run_model
      else
        wait_for_circuit_recovery
        raw_model = @server.model(model_id, max_tokens: 2048)
        @logger ? LoggingModelWrapper.new(raw_model, @logger) : raw_model
      end
    end

    def wait_for_circuit_recovery
      return unless circuit_open?

      puts "    [!] Circuit open, resetting and waiting..."
      @logger&.info("Circuit open - resetting and waiting 5s")
      reset_circuits!
      sleep 5 # rubocop:disable Smolagents/NoSleep -- Circuit recovery pause is intentional
    end

    def build_agent(model, test)
      builder = Smolagents.agent.model { model }
      test[:tools]&.each { |tool_name| builder = add_tool(builder, tool_name) }
      builder.build
    end

    def add_tool(builder, tool_name)
      tool = TestDefinitions::TOOLS[tool_name]
      return builder unless tool

      impl = wrap_tool_impl(tool_name, tool[:impl])
      inputs = tool[:inputs] || {}
      builder.tool(tool_name, tool[:desc], **inputs, &impl)
    end

    def wrap_tool_impl(tool_name, impl)
      return impl unless @logger

      proc do |**args|
        result = impl.call(**args)
        @logger.tool_call(tool_name, args, result)
        result
      end
    end

    # rubocop:disable Smolagents/NoTimeoutBlock -- Test execution requires timeout
    def execute_test(agent, test, timeout)
      result = Timeout.timeout(timeout) { agent.run(test[:task]) }
      output = result.output.to_s
      steps = result.steps.count { |s| s.is_a?(Smolagents::Types::ActionStep) }
      passed = check_result(test, output)

      log_success(test, output, steps)
      make_success_result(test, output, steps, passed)
    end
    # rubocop:enable Smolagents/NoTimeoutBlock

    def check_result(test, output)
      test[:check] ? test[:check].call(output) : output.downcase.include?(test[:expect].to_s.downcase)
    end

    def log_success(test, output, steps)
      @logger&.test_result(test[:name], true,
                           duration: "#{elapsed_time.round(2)}s",
                           output: output[0..100],
                           steps:)
    end

    def make_success_result(test, output, steps, passed)
      TestResult.new(name: test[:name], passed:, steps:,
                     duration: elapsed_time, output: output[0..200], error: nil)
    end

    def handle_timeout_error(test, timeout)
      @logger&.error("TIMEOUT after #{timeout}s")
      @logger&.test_result(test[:name], false, error: "TIMEOUT")
      make_error_result(test, timeout, "TIMEOUT after #{timeout}s")
    end

    def handle_server_error(error, model_id, test, timeout, retries)
      @logger&.error("Server error: #{error.class.name} - #{error.message}")
      if retries.positive?
        @logger&.info("Retrying after backoff (#{retries} retries left)")
        enter_backoff!(seconds: 15)
        return run_test(model_id, test, timeout:, retries: retries - 1)
      end
      @logger&.test_result(test[:name], false, error: "SERVER_ERROR")
      make_error_result(test, elapsed_time, "SERVER_ERROR: #{error.class.name}")
    end

    def handle_circuit_error(error, model_id, test, timeout, retries)
      @logger&.error("Agent generation error: #{error.message}")
      if error.message.include?("circuit open") && retries.positive?
        @logger&.info("Circuit open - backing off and retrying")
        enter_backoff!(seconds: 10)
        return run_test(model_id, test, timeout:, retries: retries - 1)
      end
      @logger&.test_result(test[:name], false, error: "CIRCUIT_OPEN")
      make_error_result(test, elapsed_time, "CIRCUIT_OPEN")
    end

    def handle_standard_error(error, test)
      @logger&.error("#{error.class}: #{error.message}")
      @logger&.info("Backtrace: #{error.backtrace&.first(3)&.join("\n")}")
      @logger&.test_result(test[:name], false, error: error.message[0..100])
      make_error_result(test, elapsed_time, "#{error.class}: #{error.message[0..100]}")
    end

    def make_error_result(test, duration, error_msg)
      TestResult.new(name: test[:name], passed: false, steps: 0,
                     duration:, output: nil, error: error_msg)
    end

    def elapsed_time = Time.now - @test_start
  end
end
