#!/usr/bin/env ruby
# Test examples against real LLM to find failure states.
# Logs FULL prompts and responses to files for analysis.
#
# Usage: ruby script/reliability/test_real_model.rb [model_id]
# Example: ruby script/reliability/test_real_model.rb LFM2.5-1.2B-Instruct-Q8_0

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "smolagents"
require_relative "logging"
require_relative "config"
require_relative "../../examples/tools/02_class_tools"

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

  # Real model tests - subset of examples that are feasible for small models
  module RealModelTests
    # Start with simple tests, progressively harder
    TESTS = [
      # =======================================================================
      # TIER 1: Trivial - Should pass on any model
      # =======================================================================
      {
        name: "trivial_math",
        tier: 1,
        description: "Simple arithmetic without tools",
        setup: ->(model) { Smolagents.agent.model { model }.build },
        task: "What is 2 + 2?",
        expect: "4"
      },
      {
        name: "trivial_fact",
        tier: 1,
        description: "Simple factual question",
        setup: ->(model) { Smolagents.agent.model { model }.build },
        task: "What is the capital of France?",
        expect: "Paris"
      },

      # =======================================================================
      # TIER 2: Basic tool use - Single tool, obvious usage
      # =======================================================================
      {
        name: "basic_calculator",
        tier: 2,
        description: "Use calculator tool for math",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:calculate, "Evaluate a math expression and return the result",
                          expression: String) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval
                    .build
        },
        task: "Use the calculate tool to compute 15 * 3",
        expect: "45"
      },
      {
        name: "basic_string_tool",
        tier: 2,
        description: "Use string manipulation tool",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:reverse, "Reverse a string", text: String) { |text:| text.reverse }
                    .build
        },
        task: "Use the reverse tool to reverse the word 'hello'",
        expect: "olleh"
      },
      {
        name: "basic_search",
        tier: 2,
        description: "Use search tool",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:search, "Search for information about a topic",
                          query: String) { |query:| "Found: #{query} is a programming language" }
                    .build
        },
        task: "Search for information about Ruby",
        expect: "Ruby"
      },

      # =======================================================================
      # TIER 3: Tool with multiple params
      # =======================================================================
      {
        name: "multi_param_tool",
        tier: 3,
        description: "Tool with two required parameters",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:repeat, "Repeat text N times",
                          text: String,
                          times: Integer) { |text:, times:| text * times }
                    .build
        },
        task: "Use the repeat tool to repeat 'hi' 3 times",
        expect: "hihihi"
      },
      {
        name: "optional_param",
        tier: 3,
        description: "Tool with optional parameter",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:greet, "Generate a greeting for a person",
                          name: String,
                          formal: { type: "boolean", description: "Use formal greeting", nullable: true }) do |name:, formal: false|
                      formal ? "Good day, #{name}." : "Hey #{name}!"
          end
                    .build
        },
        task: "Greet Alice formally using the greet tool",
        expect: "Good day"
      },

      # =======================================================================
      # TIER 4: Class-based tools
      # =======================================================================
      {
        name: "class_tool",
        tier: 4,
        description: "Use class-based temperature converter",
        setup: lambda { |model|
          converter = TemperatureConverter.new
          Smolagents.agent.model { model }.tools(converter).build
        },
        task: "Convert 100 degrees Celsius to Fahrenheit using convert_temp",
        expect: "212"
      },

      # =======================================================================
      # TIER 5: Multiple tools available
      # =======================================================================
      {
        name: "tool_selection",
        tier: 5,
        description: "Choose correct tool from multiple options",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
                    .tool(:multiply, "Multiply two numbers", a: Integer, b: Integer) { |a:, b:| a * b }
                    .tool(:subtract, "Subtract two numbers", a: Integer, b: Integer) { |a:, b:| a - b }
                    .build
        },
        task: "Multiply 7 and 6 using the appropriate tool",
        expect: "42"
      },

      # =======================================================================
      # TIER 6: Diagnostic tests - MUST use tool (can't be guessed)
      # =======================================================================
      {
        name: "random_number",
        tier: 6,
        description: "Tool returns unpredictable value - MUST use tool",
        setup: lambda { |model|
          # Returns a "random" but consistent number the model can't guess
          Smolagents.agent
                    .model { model }
                    .tool(:get_secret, "Get the secret number") { 73 }
                    .build
        },
        task: "What is the secret number? Use the get_secret tool.",
        expect: "73"
      },
      {
        name: "database_lookup",
        tier: 6,
        description: "Simulates external data lookup - MUST use tool",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:lookup_user, "Look up a user's email by ID",
                          user_id: Integer, output_type: "string") { |user_id:| "user#{user_id}@example.com" }
                    .build
        },
        task: "Look up the email for user ID 42 using the lookup_user tool",
        expect: "user42@example.com"
      },
      {
        name: "explicit_tool_requirement",
        tier: 6,
        description: "Very explicit instruction to use tool",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:concat, "Concatenate two strings",
                          a: String, b: String) { |a:, b:| "#{a}#{b}" }
                    .build
        },
        task: "YOU MUST call the concat tool with a='Hello' and b='World'. Return the result.",
        expect: "HelloWorld"
      },

      # =======================================================================
      # TIER 7: Tool result processing - use tool then transform
      # =======================================================================
      {
        name: "tool_then_process",
        tier: 7,
        description: "Call tool then process the result",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:get_items, "Get a list of items") { %w[apple banana cherry] }
                    .build
        },
        task: "Use get_items to get the list, then tell me how many items there are",
        expect: "3"
      },
      {
        name: "tool_result_uppercase",
        tier: 7,
        description: "Call tool then transform result",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:get_name, "Get a name") { "alice" }
                    .build
        },
        task: "Use get_name to get a name, then return it in uppercase",
        expect: "ALICE"
      }
    ].freeze

    class << self
      def all = TESTS
      def by_tier(tier) = TESTS.select { |t| t[:tier] == tier }
      def by_name(name) = TESTS.select { |t| t[:name].include?(name) }
      def tiers = TESTS.map { |t| t[:tier] }.uniq.sort
    end
  end

  # Runner for real model tests
  class RealModelTestRunner
    def initialize(model_id: nil, provider: nil, verbose: false, tier: nil, name: nil, repeat: 1)
      @provider_name = provider || Config::DEFAULT_PROVIDER
      model_alias = model_id || Config::DEFAULT_MODEL
      @config = Config.resolve(@provider_name, model_alias)
      @model_id = @config[:model_id]
      @verbose = verbose
      @tier_filter = tier
      @name_filter = name
      @repeat_count = repeat
      @logger = Logger.new(model_id: @model_id)
      @model = create_model
      @results = []
    end

    def run_all
      tests = select_tests

      print_header(tests)
      @logger.section("REAL MODEL TESTS")
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
      tests = RealModelTests.all
      tests = tests.select { |t| t[:tier] == @tier_filter } if @tier_filter
      tests = tests.select { |t| t[:name].include?(@name_filter) } if @name_filter
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
      puts "REAL MODEL TESTS - #{@model_id}"
      puts "=" * 70
      puts "Provider: #{@provider_name}"
      puts "API: #{@config[:api_base]}"
      puts "Tests: #{tests.size}"
      puts "Log: #{@logger.log_path}"
      puts "=" * 70
    end

    def run_test(test, run: 0)
      run_suffix = @repeat_count > 1 ? " (run #{run + 1})" : ""
      puts "\n[Tier #{test[:tier]}] #{test[:name]}#{run_suffix}: #{test[:description]}"
      @logger.section("TEST: #{test[:name]}#{run_suffix}")
      @logger.info("Tier: #{test[:tier]}")
      @logger.info("Description: #{test[:description]}")
      @logger.info("Task: #{test[:task]}")
      @logger.info("Expected: #{test[:expect]}")

      start_time = Time.now

      begin
        agent = test[:setup].call(@model)
        result = agent.run(test[:task])
        elapsed = Time.now - start_time
        output = result.output.to_s

        passed = check_expectation(output, test[:expect])
        status = passed ? "✓ PASS" : "✗ FAIL"

        puts "  #{status} (#{elapsed.round(2)}s): #{truncate(output, 60)}"
        @logger.info("Output: #{output}")
        @logger.info("Elapsed: #{elapsed.round(2)}s")
        @logger.info("Steps: #{result.step_count}")
        @logger.info("Status: #{status}")

        # Log step details for debugging failures
        log_step_details(result) unless passed

        @results << {
          name: test[:name],
          tier: test[:tier],
          passed:,
          output:,
          elapsed:,
          steps: result.step_count
        }
      rescue StandardError => e
        elapsed = Time.now - start_time
        puts "  ✗ ERROR (#{elapsed.round(2)}s): #{e.class}: #{e.message}"
        @logger.error("#{e.class}: #{e.message}")
        @logger.info("Backtrace: #{e.backtrace.first(10).join("\n")}")
        @results << {
          name: test[:name],
          tier: test[:tier],
          passed: false,
          error: e.message,
          elapsed:
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
        @logger.info("Is final: #{step.respond_to?(:is_final_answer) && step.is_final_answer}")
      end
    end

    def print_summary
      passed = @results.count { |r| r[:passed] }
      total = @results.size
      rate = total.positive? ? (passed.to_f / total * 100).round(1) : 0

      puts "\n#{"=" * 70}"
      puts "RESULTS: #{passed}/#{total} (#{rate}%)"
      puts "=" * 70

      # Group by tier
      RealModelTests.tiers.each do |tier|
        tier_results = @results.select { |r| r[:tier] == tier }
        tier_passed = tier_results.count { |r| r[:passed] }
        puts "  Tier #{tier}: #{tier_passed}/#{tier_results.size}"
      end

      # List failures
      failures = @results.reject { |r| r[:passed] }
      if failures.any?
        puts "\nFailed tests:"
        failures.each do |r|
          puts "  [Tier #{r[:tier]}] #{r[:name]}"
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
      Usage: ruby script/reliability/test_real_model.rb [model] [options]

      Arguments:
        model              Model alias or full ID (default: #{Reliability::Config::DEFAULT_MODEL})

      Options:
        --provider=NAME    API provider (default: #{Reliability::Config::DEFAULT_PROVIDER})
        --tier=N           Only run tests from tier N
        --name=PATTERN     Only run tests matching pattern
        --repeat=N         Repeat each test N times (default: 1)
        --verbose          Enable verbose output
        --list             List available providers and models
        --help, -h         Show this help

      Examples:
        ruby script/reliability/test_real_model.rb                    # Default model on default provider
        ruby script/reliability/test_real_model.rb glm-q8 --provider=lm-studio
        ruby script/reliability/test_real_model.rb nemotron-q4 --tier=6
        ruby script/reliability/test_real_model.rb --list
    HELP
    exit 0
  end

  # List providers and models
  if ARGV.include?("--list")
    puts "Available providers:"
    puts Reliability::Config.list_providers
    puts
    Reliability::Config::PROVIDERS.each_key do |prov|
      puts "Models for #{prov}:"
      puts Reliability::Config.list_models(prov)
      puts
    end
    exit 0
  end

  # Parse arguments
  model_id = ARGV.find { |a| !a.start_with?("-") }
  provider = ARGV.find { |a| a.start_with?("--provider=") }&.split("=")&.last
  tier = ARGV.find { |a| a.start_with?("--tier=") }&.split("=")&.last&.to_i
  name = ARGV.find { |a| a.start_with?("--name=") }&.split("=")&.last
  repeat = (ARGV.find { |a| a.start_with?("--repeat=") }&.split("=")&.last || "1").to_i
  verbose = ARGV.include?("--verbose")

  puts "Starting real model tests..."
  puts "Provider: #{provider || Reliability::Config::DEFAULT_PROVIDER}"
  puts "Model: #{model_id || Reliability::Config::DEFAULT_MODEL}"
  puts "Tier filter: #{tier || "all"}"
  puts "Name filter: #{name || "none"}"
  puts "Repeat: #{repeat}x"
  puts

  runner = Reliability::RealModelTestRunner.new(model_id:, provider:, verbose:, tier:, name:, repeat:)
  runner.run_all
end
