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
                          formal: { type: "boolean", description: "Use formal style", nullable: true }) do |name:, formal: false|
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
      {
        name: "inline_integer_param",
        description: "Inline tool with Integer parameter",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:repeat, "Repeat text N times",
                          text: String,
                          times: Integer) { |text:, times:| text * times }
                    .build
        },
        task: "Repeat 'hi' 3 times",
        expect: "hihihi",
        solution: "@result = repeat(text: \"hi\", times: 3)\nfinal_answer(answer: @result)"
      },
      {
        name: "inline_array_param",
        description: "Inline tool with Array parameter",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:join_words, "Join words with separator",
                          words: { type: "array", description: "Words to join" },
                          sep: { type: "string", description: "Separator", nullable: true }) do |words:, sep: " "|
                      words.join(sep)
          end
                    .build
        },
        task: "Join the words 'a', 'b', 'c' with dashes",
        expect: "a-b-c",
        solution: "@result = join_words(words: [\"a\", \"b\", \"c\"], sep: \"-\")\nfinal_answer(answer: @result)"
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
      },

      # =======================================================================
      # PLANNING - Pre-Act pattern
      # =======================================================================
      {
        name: "planning_basic",
        description: "Agent with planning enabled (default interval)",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .planning
                    .tool(:search, "Search for info", query: String) { |query:| "Info about #{query}" }
                    .build
        },
        task: "Research Ruby programming",
        expect: "Ruby",
        solution: "@info = search(query: \"Ruby programming\")\nfinal_answer(answer: @info)",
        planning_solution: "1. Search for Ruby programming information\n2. Summarize findings\n3. Return the answer"
      },
      {
        name: "planning_custom_interval",
        description: "Agent with custom planning interval",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .planning(5)
                    .tool(:lookup, "Look up facts", topic: String) { |topic:| "Fact: #{topic} is interesting" }
                    .build
        },
        task: "Find facts about space",
        expect: "space",
        solution: "@fact = lookup(topic: \"space\")\nfinal_answer(answer: @fact)",
        planning_solution: "1. Look up facts about space\n2. Return the interesting fact"
      },

      # =======================================================================
      # MEMORY - Token budget and strategies
      # =======================================================================
      {
        name: "memory_budget",
        description: "Agent with token budget memory",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .memory(budget: 50_000)
                    .tool(:fetch, "Fetch data", source: String) { |source:| "Data from #{source}" }
                    .build
        },
        task: "Fetch data from API",
        expect: "Data from API",
        solution: "@data = fetch(source: \"API\")\nfinal_answer(answer: @data)"
      },
      {
        name: "memory_with_strategy",
        description: "Agent with mask memory strategy",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .memory(budget: 100_000, strategy: :mask)
                    .tool(:process, "Process input", input: String) { |input:| input.upcase }
                    .build
        },
        task: "Process the text 'hello'",
        expect: "HELLO",
        solution: "@result = process(input: \"hello\")\nfinal_answer(answer: @result)"
      },

      # =======================================================================
      # REFINEMENT - Self-improve pattern
      # =======================================================================
      {
        name: "refinement_basic",
        description: "Agent with basic refinement",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .refine
                    .tool(:compute, "Compute result", expr: String) { |expr:| eval(expr) } # rubocop:disable Security/Eval
                    .build
        },
        task: "Compute 10 + 5",
        expect: "15",
        solution: "@result = compute(expr: \"10 + 5\")\nfinal_answer(answer: @result)"
      },
      {
        name: "refinement_with_iterations",
        description: "Agent with custom max refinement iterations",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .refine(max_iterations: 2)
                    .tool(:validate, "Validate data", data: String) { |data:| "Valid: #{data}" }
                    .build
        },
        task: "Validate 'test data'",
        expect: "Valid",
        solution: "@result = validate(data: \"test data\")\nfinal_answer(answer: @result)"
      },

      # =======================================================================
      # PERSONAS - Named agent personas
      # =======================================================================
      {
        name: "persona_researcher",
        description: "Agent with researcher persona",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .as(:researcher)
                    .tool(:search, "Search for info", query: String) { |query:| "Found: #{query}" }
                    .build
        },
        task: "Research climate change",
        expect: "climate change",
        solution: "@info = search(query: \"climate change\")\nfinal_answer(answer: @info)"
      },
      {
        name: "persona_analyst",
        description: "Agent with analyst persona",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .as(:analyst)
                    .tool(:analyze, "Analyze data", data: String) { |data:| "Analysis: #{data}" }
                    .build
        },
        task: "Analyze sales data",
        expect: "Analysis",
        solution: "@result = analyze(data: \"sales data\")\nfinal_answer(answer: @result)"
      },

      # =======================================================================
      # MANAGED AGENTS - Parent with sub-agents
      # =======================================================================
      {
        name: "managed_agent_basic",
        description: "Parent agent with managed sub-agent",
        setup: lambda { |model|
          helper = Smolagents.agent
                             .model { model }
                             .tool(:lookup, "Look up facts", topic: String) { |topic:| "Fact about #{topic}" }
                             .build

          Smolagents.agent
                    .model { model }
                    .managed_agent(helper, as: :researcher)
                    .build
        },
        task: "Ask researcher about Ruby",
        expect: "Ruby",
        solution: "@info = researcher(task: \"Tell me about Ruby\")\nfinal_answer(answer: @info)",
        helper_solution: "@fact = lookup(topic: \"Ruby\")\nfinal_answer(answer: @fact)"
      },

      # =======================================================================
      # ADVANCED - Combined features
      # =======================================================================
      {
        name: "advanced_planning_and_memory",
        description: "Agent with planning and memory budget",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .planning(3)
                    .memory(budget: 50_000)
                    .tool(:research, "Research a topic", topic: String) { |topic:| "Research on #{topic}" }
                    .build
        },
        task: "Research artificial intelligence",
        expect: "artificial intelligence",
        solution: "@info = research(topic: \"artificial intelligence\")\nfinal_answer(answer: @info)",
        planning_solution: "1. Research AI topic\n2. Summarize findings\n3. Return answer"
      },
      {
        name: "advanced_full_stack",
        description: "Agent with planning, refinement, and evaluation",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .planning(interval: 3)
                    .refine(max_iterations: 2)
                    .evaluation(enabled: true)
                    .tool(:solve, "Solve a problem", problem: String) { |problem:| "Solution: #{problem}" }
                    .build
        },
        task: "Solve the puzzle",
        expect: "Solution",
        solution: "@result = solve(problem: \"puzzle\")\nfinal_answer(answer: @result)",
        planning_solution: "1. Analyze the puzzle\n2. Solve step by step\n3. Verify solution"
      },

      # =======================================================================
      # EDGE CASES - Error handling and special scenarios
      # =======================================================================
      {
        name: "empty_tool_inputs",
        description: "Tool with no parameters",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:timestamp, "Get current timestamp") { Time.now.to_i }
                    .build
        },
        task: "Get the current timestamp",
        expect: /\d+/,
        solution: "@ts = timestamp()\nfinal_answer(answer: @ts)"
      },
      {
        name: "tool_with_description_hints",
        description: "Tool descriptions with URL and path hints",
        setup: lambda { |model|
          Smolagents.agent
                    .model { model }
                    .tool(:visit, "Visit a webpage",
                          url: { type: "string", description: "The URL to visit" }) { |url:| "Content from #{url}" }
                    .tool(:read_file, "Read a file",
                          path: { type: "string", description: "Path to the file" }) { |path:| "File: #{path}" }
                    .build
        },
        task: "Visit example.com",
        expect: "example.com",
        solution: "@content = visit(url: \"https://example.com\")\nfinal_answer(answer: @content)"
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

        passed = check_expectation(output, test[:expect])
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

    def check_expectation(output, expect)
      case expect
      when Regexp then output.match?(expect)
      when String then output.downcase.include?(expect.downcase)
      else false
      end
    end

    def inject_solution(test)
      task = test[:task]
      solution = test[:solution]
      planning_solution = test[:planning_solution]
      helper_solution = test[:helper_solution]

      @dry_run_model.define_singleton_method(:find_test_for_task) do |t|
        if t&.include?(task) || task.include?(t.to_s)
          { name: test[:name], task:, solution: }
        elsif t&.include?("Tell me about") || t&.include?("research")
          # Sub-agent task
          { name: "#{test[:name]}_helper", task: t, solution: helper_solution || solution }
        else
          nil
        end
      end

      # Override for planning prompts
      @dry_run_model.define_singleton_method(:resolve_code_for_task) do |t|
        case t
        when /Create a step-by-step plan|Review your progress/
          planning_solution || "1. Execute the task\n2. Return the result"
        when /Tell me about/
          # Sub-agent delegation task
          helper_solution || solution
        else
          solution
        end
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
