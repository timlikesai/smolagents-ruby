#!/usr/bin/env ruby
# Model Reliability Test Harness
#
# Progressive tests to find model failure modes with full logging.
# All prompts and raw responses are captured for debugging.
#
# Usage:
#   ruby script/model_reliability_harness.rb                    # Run all tests
#   ruby script/model_reliability_harness.rb --level 1          # Run specific level
#   ruby script/model_reliability_harness.rb --model gemma-3n   # Specific model
#   ruby script/model_reliability_harness.rb --list-models      # Show available models

require_relative "../lib/smolagents"
require "fileutils"
require "json"
require "optparse"

module ModelReliabilityHarness
  # Verbose logger that captures everything for debugging
  class VerboseLogger
    attr_reader :log_dir, :session_id

    def initialize(log_dir: "logs/reliability")
      @log_dir = log_dir
      @session_id = Time.now.strftime("%Y%m%d-%H%M%S")
      FileUtils.mkdir_p(log_dir)
      @log_file = File.open(log_path, "w")
      @log_file.sync = true
    end

    def log_path = File.join(@log_dir, "#{@session_id}_reliability.log")

    def section(title)
      write("\n#{"=" * 80}")
      write("[#{timestamp}] #{title}")
      write("=" * 80)
    end

    def subsection(title)
      write("\n#{"-" * 60}")
      write("[#{timestamp}] #{title}")
      write("-" * 60)
    end

    def info(msg) = write("[#{timestamp}] #{msg}")
    def success(msg) = write("[#{timestamp}] ✓ #{msg}")
    def failure(msg) = write("[#{timestamp}] ✗ #{msg}")
    def error(msg) = write("[#{timestamp}] ERROR: #{msg}")

    def prompt(messages)
      subsection("PROMPT SENT TO MODEL")
      messages.each_with_index do |msg, i|
        write("--- Message #{i + 1} (#{msg.role}) ---")
        content = msg.content.is_a?(String) ? msg.content : msg.content.to_json
        write(content)
      end
    end

    def raw_response(response)
      subsection("RAW MODEL RESPONSE")
      if response.respond_to?(:raw)
        write(JSON.pretty_generate(response.raw))
      else
        write(response.to_s)
      end
    end

    def parsed_output(content, code: nil)
      subsection("PARSED OUTPUT")
      write("Content: #{content}")
      write("Extracted code:\n#{code}") if code
    end

    def test_result(name, passed, details = {})
      status = passed ? "PASS" : "FAIL"
      subsection("TEST RESULT: #{name} - #{status}")
      details.each { |k, v| write("  #{k}: #{v}") }
    end

    def close
      @log_file&.close
      puts "\nLog saved to: #{log_path}"
    end

    private

    def timestamp = Time.now.strftime("%H:%M:%S.%L")

    def write(msg)
      @log_file.puts(msg)
      puts msg # Also print to console
    end
  end

  # Wraps a model to intercept all calls for logging
  class LoggingModelWrapper
    attr_reader :wrapped_model, :logger

    def initialize(model, logger)
      @wrapped_model = model
      @logger = logger
    end

    def model_id = @wrapped_model.model_id

    def generate(messages, **)
      @logger.prompt(messages)
      response = @wrapped_model.generate(messages, **)
      @logger.raw_response(response)
      @logger.parsed_output(response.content)
      response
    end

    def method_missing(method, ...) = @wrapped_model.send(method, ...)
    def respond_to_missing?(method, include_private = false) = @wrapped_model.respond_to?(method, include_private)
  end

  # Test definitions with progressive complexity
  module TestSuites
    LEVEL_1_BASIC = [
      {
        name: "simple_math",
        task: "What is 2 + 2? Reply with just the number.",
        validate: ->(result) { result.output.to_s.include?("4") },
        description: "Basic arithmetic, no tools"
      },
      {
        name: "simple_greeting",
        task: "Say hello in exactly 3 words.",
        validate: ->(result) { result.output.to_s.split.size <= 5 },
        description: "Follow simple format instructions"
      },
      {
        name: "direct_answer",
        task: "What color is the sky on a clear day? One word answer.",
        validate: ->(result) { result.output.to_s.downcase.include?("blue") },
        description: "Factual recall with format constraint"
      }
    ].freeze

    LEVEL_2_CODE_EXECUTION = [
      {
        name: "ruby_arithmetic",
        task: "Calculate 15 * 7 using Ruby code.",
        validate: ->(result) { result.output.to_s.include?("105") },
        description: "Generate and execute Ruby arithmetic"
      },
      {
        name: "ruby_string",
        task: "Reverse the string 'hello' using Ruby.",
        validate: ->(result) { result.output.to_s.include?("olleh") },
        description: "String manipulation in Ruby"
      },
      {
        name: "ruby_array",
        task: "Create an array [1,2,3,4,5] and sum all elements.",
        validate: ->(result) { result.output.to_s.include?("15") },
        description: "Array operations"
      }
    ].freeze

    LEVEL_3_SINGLE_TOOL = [
      {
        name: "tool_basic",
        task: "Use the add tool to add 10 and 20.",
        tools: [{ name: :add, desc: "Add two numbers", impl: ->(a:, b:) { a + b } }],
        validate: ->(result) { result.output.to_s.include?("30") },
        description: "Single tool call with explicit instruction"
      },
      {
        name: "tool_implicit",
        task: "What is 8 times 9?",
        tools: [{ name: :multiply, desc: "Multiply two numbers", impl: ->(a:, b:) { a * b } }],
        validate: ->(result) { result.output.to_s.include?("72") },
        description: "Tool use without explicit instruction"
      },
      {
        name: "tool_with_result",
        task: "Look up information about Ruby programming language.",
        tools: [{ name: :lookup, desc: "Look up info about a topic", impl: lambda { |topic:|
          "#{topic} is a dynamic language"
        } }],
        validate: ->(result) { result.output.to_s.downcase.include?("dynamic") },
        description: "Tool that returns text to incorporate"
      }
    ].freeze

    LEVEL_4_MULTI_STEP = [
      {
        name: "two_step_math",
        task: "First add 5 and 3, then multiply that result by 2.",
        tools: [
          { name: :add, desc: "Add two numbers", impl: ->(a:, b:) { a + b } },
          { name: :multiply, desc: "Multiply two numbers", impl: ->(a:, b:) { a * b } }
        ],
        validate: ->(result) { result.output.to_s.include?("16") },
        description: "Sequential tool calls with dependency"
      },
      {
        name: "store_and_recall",
        task: "Store the number 42, then retrieve it and add 8 to it.",
        tools: [
          { name: :store, desc: "Store a value", impl: lambda { |value:|
            $test_store = value
            "stored #{value}"
          } },
          { name: :retrieve, desc: "Retrieve stored value", impl: -> { $test_store || 0 } },
          { name: :add, desc: "Add two numbers", impl: ->(a:, b:) { a + b } }
        ],
        validate: ->(result) { result.output.to_s.include?("50") },
        description: "State management across steps"
      },
      {
        name: "conditional_logic",
        task: "Check if 10 is greater than 5. If yes, return 'big', otherwise return 'small'.",
        validate: ->(result) { result.output.to_s.downcase.include?("big") },
        description: "Conditional logic in code"
      }
    ].freeze

    LEVEL_5_COMPLEX_REASONING = [
      {
        name: "multi_step_calculation",
        task: "Calculate the average of [10, 20, 30, 40, 50] and round to nearest integer.",
        validate: ->(result) { result.output.to_s.include?("30") },
        description: "Multi-step calculation with built-in Ruby"
      },
      {
        name: "data_transformation",
        task: "Given the hash {a: 1, b: 2, c: 3}, double all values and return the sum.",
        validate: ->(result) { result.output.to_s.include?("12") },
        description: "Hash transformation and aggregation"
      },
      {
        name: "string_analysis",
        task: "Count how many vowels are in the word 'extraordinary'.",
        validate: ->(result) { result.output.to_s.include?("6") },
        description: "String analysis requiring iteration"
      }
    ].freeze

    LEVEL_6_AGENT_PATTERNS = [
      {
        name: "error_recovery",
        task: "Try to divide 10 by 0. Handle the error and return 'undefined'.",
        validate: lambda { |result|
          result.output.to_s.downcase.include?("undefined") || result.output.to_s.include?("infinity")
        },
        description: "Error handling and recovery"
      },
      {
        name: "iterative_refinement",
        task: "Generate a list of 3 prime numbers less than 20.",
        validate: lambda { |result|
          primes = [2, 3, 5, 7, 11, 13, 17, 19]
          primes.count { |p| result.output.to_s.include?(p.to_s) } >= 3
        },
        description: "Generate and validate results"
      },
      {
        name: "format_compliance",
        task: "Return exactly this JSON: {\"status\": \"ok\", \"count\": 42}",
        validate: lambda { |result|
          output = result.output.to_s
          output.include?('"status"') && output.include?("ok") && output.include?("42")
        },
        description: "Strict format compliance"
      }
    ].freeze

    LEVEL_7_META_AGENT = [
      {
        name: "code_generation",
        task: "Write a Ruby method called 'double' that takes a number and returns it multiplied by 2. Then use it to double 21.",
        validate: ->(result) { result.output.to_s.include?("42") },
        description: "Define and use a method"
      },
      {
        name: "dsl_understanding",
        task: <<~TASK,
          You have access to a DSL for building agents. Create a simple agent config:
          - It should have a model
          - It should have one tool called 'greet' that says hello

          Just describe what the configuration would look like, don't execute anything.
        TASK
        validate: lambda { |result|
          out = result.output.to_s.downcase
          out.include?("model") && out.include?("tool") && out.include?("greet")
        },
        description: "Understanding and describing DSL patterns"
      }
    ].freeze

    ALL_LEVELS = {
      1 => { name: "Basic", tests: LEVEL_1_BASIC },
      2 => { name: "Code Execution", tests: LEVEL_2_CODE_EXECUTION },
      3 => { name: "Single Tool", tests: LEVEL_3_SINGLE_TOOL },
      4 => { name: "Multi-Step", tests: LEVEL_4_MULTI_STEP },
      5 => { name: "Complex Reasoning", tests: LEVEL_5_COMPLEX_REASONING },
      6 => { name: "Agent Patterns", tests: LEVEL_6_AGENT_PATTERNS },
      7 => { name: "Meta-Agent", tests: LEVEL_7_META_AGENT }
    }.freeze
  end

  # Test runner
  class Runner
    def initialize(server_url:, logger:)
      @server = Smolagents::Servers::LlamaCpp.new(api_base: server_url)
      @logger = logger
    end

    def available_models
      @server.models.reject(&:failed?)
    end

    def run_test(model_id, test, timeout: 60)
      @logger.section("TEST: #{test[:name]}")
      @logger.info("Description: #{test[:description]}")
      @logger.info("Task: #{test[:task]}")

      # IMPORTANT: Fresh agent for each test to avoid context bleeding
      raw_model = @server.model(model_id, max_tokens: 2048)
      wrapped_model = LoggingModelWrapper.new(raw_model, @logger)

      builder = Smolagents.agent.model { wrapped_model }

      # Add tools if specified
      test[:tools]&.each do |tool|
        builder = builder.tool(tool[:name], tool[:desc], &tool[:impl])
      end

      agent = builder.build

      start_time = Time.now
      result = Timeout.timeout(timeout) { agent.run(test[:task]) }
      duration = Time.now - start_time

      passed = test[:validate].call(result)
      @logger.test_result(test[:name], passed,
                          duration: "#{duration.round(2)}s",
                          output: result.output.to_s.lines.first&.chomp,
                          steps: result.steps.count { |s| s.is_a?(Smolagents::Types::ActionStep) })

      { name: test[:name], passed:, duration:, output: result.output, error: nil }
    rescue Timeout::Error
      @logger.failure("Timeout after #{timeout}s")
      { name: test[:name], passed: false, duration: timeout, output: nil, error: "Timeout" }
    rescue StandardError => e
      @logger.error("#{e.class}: #{e.message}")
      @logger.info(e.backtrace.first(5).join("\n"))
      { name: test[:name], passed: false, duration: 0, output: nil, error: e.message }
    end

    def run_level(model_id, level, timeout: 60)
      level_info = TestSuites::ALL_LEVELS[level]
      @logger.section("LEVEL #{level}: #{level_info[:name]}")
      @logger.info("Model: #{model_id}")
      @logger.info("Tests: #{level_info[:tests].size}")

      results = level_info[:tests].map { |test| run_test(model_id, test, timeout:) }

      passed = results.count { |r| r[:passed] }
      @logger.subsection("LEVEL #{level} SUMMARY")
      @logger.info("Passed: #{passed}/#{results.size}")

      results
    end

    def run_all_levels(model_id, levels: 1..7, timeout: 60, stop_on_failure: false)
      all_results = {}

      levels.each do |level|
        next unless TestSuites::ALL_LEVELS.key?(level)

        results = run_level(model_id, level, timeout:)
        all_results[level] = results

        if stop_on_failure && results.any? { |r| !r[:passed] }
          @logger.info("Stopping at level #{level} due to failures")
          break
        end
      end

      all_results
    end
  end
end

# CLI
if __FILE__ == $PROGRAM_NAME
  options = {
    server: "https://llama-cpp-ultra.reverse-bull.ts.net",
    level: nil,
    model: nil,
    timeout: 60,
    stop_on_failure: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on("--server URL", "Server URL") { |v| options[:server] = v }
    opts.on("--level N", Integer, "Run specific level (1-7)") { |v| options[:level] = v }
    opts.on("--model ID", "Model ID (partial match ok)") { |v| options[:model] = v }
    opts.on("--timeout N", Integer, "Timeout per test") { |v| options[:timeout] = v }
    opts.on("--stop-on-failure", "Stop when a test fails") { options[:stop_on_failure] = true }
    opts.on("--list-models", "List available models") { options[:list] = true }
  end.parse!

  logger = ModelReliabilityHarness::VerboseLogger.new
  runner = ModelReliabilityHarness::Runner.new(server_url: options[:server], logger:)

  if options[:list]
    puts "\nAvailable models:"
    runner.available_models.each do |m|
      status = m.loaded? ? "(loaded)" : "(unloaded)"
      puts "  #{m.id} #{status}"
    end
    exit 0
  end

  # Find model
  models = runner.available_models
  target_model = if options[:model]
                   models.find { |m| m.id.downcase.include?(options[:model].downcase) }
                 else
                   models.find(&:loaded?) || models.first
                 end

  unless target_model
    puts "No model found. Use --list-models to see available models."
    exit 1
  end

  logger.section("MODEL RELIABILITY TEST")
  logger.info("Model: #{target_model.id}")
  logger.info("Status: #{target_model.status}")

  begin
    levels = options[:level] ? [options[:level]] : (1..7)
    results = runner.run_all_levels(
      target_model.id,
      levels:,
      timeout: options[:timeout],
      stop_on_failure: options[:stop_on_failure]
    )

    # Final summary
    logger.section("FINAL SUMMARY")
    total_passed = 0
    total_tests = 0

    results.each do |level, level_results|
      passed = level_results.count { |r| r[:passed] }
      total = level_results.size
      total_passed += passed
      total_tests += total
      logger.info("Level #{level}: #{passed}/#{total}")
    end

    logger.info("")
    logger.info("Overall: #{total_passed}/#{total_tests} (#{(total_passed.to_f / total_tests * 100).round(1)}%)")
  ensure
    logger.close
  end
end
