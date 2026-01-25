#!/usr/bin/env ruby
# Test model capabilities using taxonomy-based test suite.
# Logs full prompts and responses for analysis.
#
# Usage:
#   ruby script/reliability/test_capabilities.rb [model] [options]
#   ruby script/reliability/test_capabilities.rb glm-q8 --provider=lm-studio
#   ruby script/reliability/test_capabilities.rb --capability=error_recovery
#   ruby script/reliability/test_capabilities.rb --tag=must_use_tool
#   ruby script/reliability/test_capabilities.rb --list

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "smolagents"
require_relative "logging"
require_relative "config"
require_relative "capability_tests"

module Reliability
  # Wrapper to log all prompts and responses
  class LoggingModelWrapper
    attr_reader :model_id

    def initialize(model, logger)
      @model = model
      @logger = logger
      @model_id = model.model_id
    end

    def generate(messages, **)
      log_prompt(messages)
      response = @model.generate(messages, **)
      log_response(response)
      response
    end

    private

    def log_prompt(messages)
      @logger.subsection("PROMPT SENT TO MODEL")
      messages.each_with_index do |msg, i|
        role = msg.respond_to?(:role) ? msg.role : msg[:role]
        content = msg.respond_to?(:content) ? msg.content : msg[:content]
        @logger.info("=== MESSAGE #{i + 1} [#{role}] ===")
        content.to_s.each_line { |line| @logger.info(line.chomp) }
        @logger.info("=== END MESSAGE #{i + 1} ===")
      end
    end

    def log_response(response)
      @logger.subsection("MODEL RESPONSE")
      content = response.respond_to?(:content) ? response.content : response.to_s
      content.to_s.each_line { |line| @logger.info(line.chomp) }
      @logger.info("=== END RESPONSE ===")
    end
  end

  # Runner for capability-based tests
  class CapabilityTestRunner
    def initialize(model_id: nil, provider: nil, capability: nil, tag: nil, name: nil, repeat: 1, verbose: false)
      @provider_name = provider || Config::DEFAULT_PROVIDER
      model_alias = model_id || Config::DEFAULT_MODEL
      @config = Config.resolve(@provider_name, model_alias)
      @model_id = @config[:model_id]
      @capability_filter = capability&.to_sym
      @tag_filter = tag&.to_sym
      @name_filter = name
      @repeat_count = repeat
      @verbose = verbose
      @logger = Logger.new(model_id: @model_id)
      @model = create_model
      @results = []
    end

    def run_all
      tests = select_tests

      print_header(tests)
      @logger.section("CAPABILITY TESTS")
      @logger.info("Model: #{@model_id}")
      @logger.info("Tests: #{tests.size}")

      @repeat_count.times do |run|
        puts "\n--- Run #{run + 1}/#{@repeat_count} ---" if @repeat_count > 1
        tests.each { |test| run_test(test, run:) }
      end

      print_summary
      @logger.close
    end

    private

    def select_tests
      tests = CapabilityTests.all
      tests = CapabilityTests.by_capability(@capability_filter) if @capability_filter
      tests = tests.select { |t| t.tags.include?(@tag_filter) } if @tag_filter
      tests = tests.select { |t| t.name.include?(@name_filter) } if @name_filter
      tests
    end

    def create_model
      model = Smolagents::Models::OpenAIModel.new(
        model_id: @model_id,
        api_base: @config[:api_base],
        api_key: @config[:api_key]
      )
      LoggingModelWrapper.new(model, @logger)
    end

    def print_header(tests)
      puts "=" * 70
      puts "CAPABILITY TESTS - #{@model_id}"
      puts "=" * 70
      puts "Provider: #{@provider_name}"
      puts "API: #{@config[:api_base]}"
      puts "Tests: #{tests.size}"
      puts "Capabilities: #{tests.map(&:capability).uniq.join(", ")}"
      puts "Log: #{@logger.log_path}"
      puts "=" * 70
    end

    def run_test(test, run: 0)
      run_suffix = @repeat_count > 1 ? " (run #{run + 1})" : ""
      cap_name = test.capability.to_s.tr("_", " ")
      puts "\n[#{cap_name}] #{test.name}#{run_suffix}: #{test.description}"
      @logger.section("TEST: #{test.name}#{run_suffix}")
      @logger.info("Capability: #{test.capability}")
      @logger.info("Description: #{test.description}")
      @logger.info("Task: #{test.task}")
      @logger.info("Expected: #{test.expect}")
      @logger.info("Tags: #{test.tags.join(", ")}") if test.tags.any?

      start_time = Time.now

      begin
        agent = test.setup.call(@model)
        result = agent.run(test.task)
        elapsed = Time.now - start_time
        output = result.output.to_s

        passed = check_expectation(output, test.expect)
        status = passed ? "\u2713 PASS" : "\u2717 FAIL"
        failure_mode = classify_failure(test, result, output) unless passed

        puts "  #{status} (#{elapsed.round(2)}s): #{truncate(output, 60)}"
        puts "    Failure mode: #{failure_mode}" if failure_mode

        @logger.info("Output: #{output}")
        @logger.info("Elapsed: #{elapsed.round(2)}s")
        @logger.info("Steps: #{result.step_count}")
        @logger.info("Status: #{status}")
        @logger.info("Failure mode: #{failure_mode}") if failure_mode

        log_step_details(result) unless passed

        @results << {
          name: test.name,
          capability: test.capability,
          tags: test.tags,
          passed:,
          output:,
          elapsed:,
          steps: result.step_count,
          failure_mode:
        }
      rescue StandardError => e
        elapsed = Time.now - start_time
        puts "  \u2717 ERROR (#{elapsed.round(2)}s): #{e.class}: #{e.message}"
        @logger.error("#{e.class}: #{e.message}")
        @logger.info("Backtrace: #{e.backtrace.first(10).join("\n")}")
        @results << {
          name: test.name,
          capability: test.capability,
          tags: test.tags,
          passed: false,
          error: e.message,
          elapsed:,
          failure_mode: :runtime_error
        }
      end
    end

    def check_expectation(output, expect)
      case expect
      when Regexp then output.match?(expect)
      when String then output.downcase.include?(expect.downcase)
      else false
      end
    end

    def classify_failure(test, result, output)
      # Attempt to classify the failure mode
      return :tool_not_called if test.tags.include?(:must_use_tool) && result.step_count <= 1
      return :hallucinated_answer if output.empty? || output.length < 2
      return :wrong_interpretation if result.step_count > 1 && !output.empty?

      :unknown
    end

    def truncate(str, len)
      str.length > len ? "#{str[0...len]}..." : str
    end

    def log_step_details(result)
      @logger.subsection("STEP DETAILS (for debugging)")
      result.steps.each_with_index do |step, i|
        @logger.info("--- Step #{i + 1} ---")
        if step.respond_to?(:model_output_message)
          content = step.model_output_message&.content
          @logger.info("Model output: #{content&.slice(0, 500)}")
        end
        @logger.info("Observations: #{step.observations&.slice(0, 500)}") if step.respond_to?(:observations)
        @logger.info("Is final: #{step.respond_to?(:final_answer) && step.final_answer}")
      end
    end

    def print_summary
      passed = @results.count { |r| r[:passed] }
      total = @results.size
      rate = total.positive? ? (passed.to_f / total * 100).round(1) : 0

      puts "\n#{"=" * 70}"
      puts "RESULTS: #{passed}/#{total} (#{rate}%)"
      puts "=" * 70

      # Group by capability
      CapabilityTests.capabilities.each do |cap|
        cap_results = @results.select { |r| r[:capability] == cap }
        next if cap_results.empty?

        cap_passed = cap_results.count { |r| r[:passed] }
        cap_name = cap.to_s.tr("_", " ").capitalize
        puts "  #{cap_name}: #{cap_passed}/#{cap_results.size}"
      end

      # Failure mode summary
      failure_modes = @results.reject { |r| r[:passed] }.group_by { |r| r[:failure_mode] }
      if failure_modes.any?
        puts "\nFailure modes:"
        failure_modes.each do |mode, failures|
          puts "  #{mode}: #{failures.size} (#{failures.map { |f| f[:name] }.join(", ")})"
        end
      end

      # List failures
      failures = @results.reject { |r| r[:passed] }
      if failures.any?
        puts "\nFailed tests:"
        failures.each do |r|
          puts "  [#{r[:capability]}] #{r[:name]}"
          puts "    #{r[:error] || truncate(r[:output].to_s, 60)}"
        end
      end

      puts "\nLog saved to: #{@logger.log_path}"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  # Show help
  if ARGV.include?("--help") || ARGV.include?("-h")
    puts <<~HELP
      Usage: ruby script/reliability/test_capabilities.rb [model] [options]

      Arguments:
        model              Model alias or full ID (default: #{Reliability::Config::DEFAULT_MODEL})

      Options:
        --provider=NAME    API provider (default: #{Reliability::Config::DEFAULT_PROVIDER})
        --capability=NAME  Only run tests for this capability
        --tag=NAME         Only run tests with this tag
        --name=PATTERN     Only run tests matching pattern
        --repeat=N         Repeat each test N times (default: 1)
        --verbose          Enable verbose output
        --list             List available capabilities and tests
        --help, -h         Show this help

      Capabilities:
        #{Reliability::CapabilityTests.capabilities.join(", ")}

      Tags:
        must_use_tool, should_not_use_tool, error_handling, paraphrase, distractors, verbose, edge_case

      Examples:
        ruby script/reliability/test_capabilities.rb
        ruby script/reliability/test_capabilities.rb glm-q8 --provider=lm-studio
        ruby script/reliability/test_capabilities.rb --capability=error_recovery
        ruby script/reliability/test_capabilities.rb --tag=must_use_tool
        ruby script/reliability/test_capabilities.rb --list
    HELP
    exit 0
  end

  # List capabilities and tests
  if ARGV.include?("--list")
    puts "Capabilities and tests:\n\n"
    Reliability::CapabilityTests.capabilities.each do |cap|
      tests = Reliability::CapabilityTests.by_capability(cap)
      puts "#{cap} (#{tests.size} tests):"
      tests.each do |t|
        tags = t.tags.any? ? " [#{t.tags.join(", ")}]" : ""
        puts "  #{t.name}: #{t.description}#{tags}"
      end
      puts
    end
    exit 0
  end

  # Parse arguments
  model_id = ARGV.find { |a| !a.start_with?("-") }
  provider = ARGV.find { |a| a.start_with?("--provider=") }&.split("=")&.last
  capability = ARGV.find { |a| a.start_with?("--capability=") }&.split("=")&.last
  tag = ARGV.find { |a| a.start_with?("--tag=") }&.split("=")&.last
  name = ARGV.find { |a| a.start_with?("--name=") }&.split("=")&.last
  repeat = (ARGV.find { |a| a.start_with?("--repeat=") }&.split("=")&.last || "1").to_i
  verbose = ARGV.include?("--verbose")

  puts "Starting capability tests..."
  puts "Provider: #{provider || Reliability::Config::DEFAULT_PROVIDER}"
  puts "Model: #{model_id || Reliability::Config::DEFAULT_MODEL}"
  puts "Capability filter: #{capability || "all"}"
  puts "Tag filter: #{tag || "none"}"
  puts "Name filter: #{name || "none"}"
  puts "Repeat: #{repeat}x"
  puts

  runner = Reliability::CapabilityTestRunner.new(
    model_id:, provider:, capability:, tag:, name:, repeat:, verbose:
  )
  runner.run_all
end
