#!/usr/bin/env ruby
# Test examples through dry-run to verify prompt generation and tool signatures.
# Logs FULL prompts to files for inspection.
#
# Usage: ruby script/reliability/test_examples.rb

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "smolagents"
require_relative "logging"
require_relative "test_definitions"
require_relative "dry_run_model"
require_relative "../../examples/tools/02_class_tools"

module Reliability
  # Tests based on actual examples to verify the full pipeline
  module ExampleTests
    TESTS = [
      # =======================================================================
      # BASICS - Minimal agents
      # =======================================================================
      {
        name: "minimal_agent",
        description: "Simplest agent with no tools",
        setup: ->(model) { Smolagents.agent.model { model }.build },
        task: "What is 2 + 2?",
        expect: "4",
        solution: "final_answer(answer: 4)"
      },
      {
        name: "agent_with_instructions",
        description: "Agent with custom instructions",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .instructions("Always be concise.")
                    .build
        },
        task: "What is the capital of France?",
        expect: "Paris",
        solution: 'final_answer(answer: "Paris")'
      },

      # =======================================================================
      # INLINE TOOLS - Tool signature verification
      # =======================================================================
      {
        name: "inline_calculator",
        description: "Inline tool with String input",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:calculate, "Evaluate a math expression",
                          expression: String) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval
                    .build
        },
        task: "Calculate 15 * 3",
        expect: "45",
        solution: "@result = calculate(expression: \"15 * 3\")\nfinal_answer(answer: @result)"
      },
      {
        name: "inline_string_tools",
        description: "Multiple inline tools",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:reverse, "Reverse a string", text: String) { |text:| text.reverse }
                    .tool(:uppercase, "Convert to uppercase", text: String) { |text:| text.upcase }
                    .build
        },
        task: "Reverse the word 'hello'",
        expect: "olleh",
        solution: "@result = reverse(text: \"hello\")\nfinal_answer(answer: @result)"
      },
      {
        name: "inline_optional_param",
        description: "Inline tool with optional boolean parameter",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:greet, "Generate a greeting",
                          name: String,
                          formal: { type: "boolean", nullable: true }) do |name:, formal: false|
                      formal ? "Good day, #{name}." : "Hey #{name}!"
                    end
                    .build
        },
        task: "Greet Alice formally",
        expect: "Good day, Alice",
        solution: "@result = greet(name: \"Alice\", formal: true)\nfinal_answer(answer: @result)"
      },
      {
        name: "inline_structured_output",
        description: "Inline tool returning hash",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:analyze, "Analyze text statistics", text: String) do |text:|
                      { length: text.length, words: text.split.count }
                    end
                    .build
        },
        task: "Analyze 'hello world'",
        expect: "words",
        solution: "@stats = analyze(text: \"hello world\")\nfinal_answer(answer: @stats)"
      },

      # =======================================================================
      # CLASS TOOLS - Complex tool verification
      # =======================================================================
      {
        name: "class_tool_temperature",
        description: "Class-based tool with structured input/output",
        setup: lambda { |model|
          converter = TemperatureConverter.new
          Smolagents.agent.model { model }.tools(converter).build
        },
        task: "Convert 100 degrees Celsius to Fahrenheit",
        expect: "212",
        solution: "@result = convert_temp(value: 100, from_unit: \"C\")\nfinal_answer(answer: @result[:value])"
      },
      {
        name: "class_tool_counter",
        description: "Stateful class tool",
        setup: lambda { |model|
          counter = CounterTool.new
          Smolagents.agent.model { model }.tools(counter).build
        },
        task: "Increment the counter twice and tell me the value",
        expect: "2",
        solution: "counter()\n@result = counter()\nfinal_answer(answer: @result)"
      },
      {
        name: "class_tool_search",
        description: "Configurable class tool",
        setup: lambda { |model|
          search = SearchTool.new(max_results: 3)
          Smolagents.agent.model { model }.tools(search).build
        },
        task: "Search for 'Ruby programming'",
        expect: "Result",
        solution: "@results = search(query: \"Ruby programming\")\nfinal_answer(answer: @results.first)"
      },
      {
        name: "class_tool_analysis",
        description: "Tool with output schema",
        setup: lambda { |model|
          analyzer = AnalysisTool.new
          Smolagents.agent.model { model }.tools(analyzer).build
        },
        task: "Analyze the text 'Hello world. How are you?'",
        expect: "word_count",
        solution: "@stats = analyze_text(text: \"Hello world. How are you?\")\nfinal_answer(answer: @stats)"
      },

      # =======================================================================
      # MIXED TOOLS - Combining inline and class tools
      # =======================================================================
      {
        name: "mixed_tools",
        description: "Inline + class tools together",
        setup: lambda { |model|
          converter = TemperatureConverter.new
          Smolagents.agent
                    .model { model }
                    .tools(converter)
                    .tool(:double, "Double a number", n: Integer) { |n:| n * 2 }
                    .build
        },
        task: "Double the number 21",
        expect: "42",
        solution: "@result = double(n: 21)\nfinal_answer(answer: @result)"
      }
    ].freeze

    class << self
      def all = TESTS
      def count = TESTS.size
    end
  end

  # Runner for example tests
  class ExampleTestRunner
    def initialize(verbose: true)
      @verbose = verbose
      @logger = Logger.new(model_id: "examples")
      @dry_run_model = DryRunModel.new(verbose:, logger: @logger)
      @results = []
    end

    def run_all
      puts "=" * 70
      puts "EXAMPLE TESTS - Dry Run Mode"
      puts "=" * 70
      puts "Tests: #{ExampleTests.count}"
      puts "Log: #{@logger.log_path}"
      puts "=" * 70

      @logger.section("EXAMPLE TESTS")
      @logger.info("Tests: #{ExampleTests.count}")

      ExampleTests.all.each { |test| run_test(test) }

      print_summary
      @logger.close
    end

    private

    def run_test(test)
      puts "\n#{test[:name]}: #{test[:description]}"
      @logger.section("TEST: #{test[:name]}")
      @logger.info("Description: #{test[:description]}")
      @logger.info("Task: #{test[:task]}")

      # Inject solution into model
      inject_solution(test)

      begin
        agent = test[:setup].call(@dry_run_model)
        result = agent.run(test[:task])
        output = result.output.to_s

        passed = output.downcase.include?(test[:expect].downcase)
        status = passed ? "✓ PASS" : "✗ FAIL"

        puts "  #{status}: #{output[0..60]}"
        @logger.info("Output: #{output}")
        @logger.info("Expected: #{test[:expect]}")
        @logger.info("Status: #{status}")

        @results << { name: test[:name], passed:, output: }
      rescue StandardError => e
        puts "  ✗ ERROR: #{e.class}: #{e.message}"
        @logger.error("#{e.class}: #{e.message}")
        @logger.info("Backtrace: #{e.backtrace.first(5).join("\n")}")
        @results << { name: test[:name], passed: false, error: e.message }
      end
    end

    def inject_solution(test)
      # Create a temporary test definition for the dry run model to find
      task = test[:task]
      solution = test[:solution]

      # Monkey-patch find_test_for_task to return our test
      @dry_run_model.define_singleton_method(:find_test_for_task) do |t|
        return { name: test[:name], task:, solution: } if t&.include?(task) || task.include?(t.to_s)

        nil
      end
    end

    def print_summary
      passed = @results.count { |r| r[:passed] }
      total = @results.size
      rate = (passed.to_f / total * 100).round(1)

      puts "\n#{"=" * 70}"
      puts "RESULTS: #{passed}/#{total} (#{rate}%)"
      puts "=" * 70

      @results.reject { |r| r[:passed] }.each do |r|
        puts "  FAILED: #{r[:name]}"
        puts "    #{r[:error] || r[:output]}"
      end

      puts "\nLog saved to: #{@logger.log_path}"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  runner = Reliability::ExampleTestRunner.new(verbose: ARGV.include?("--verbose"))
  runner.run_all
end
