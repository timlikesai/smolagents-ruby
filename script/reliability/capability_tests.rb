# Capability-based test taxonomy for model reliability testing.
#
# Tests are organized by conceptual capability dimensions, not difficulty levels.
# Each capability can have multiple tests of varying complexity.
#
# Capability Taxonomy:
#   :basic_reasoning     - No tools, factual Q&A, simple logic
#   :tool_invocation     - Call a single tool with correct parameters
#   :tool_selection      - Choose the right tool from multiple options
#   :parameter_handling  - Multiple params, optional params, type coercion
#   :result_interpretation - Process, transform, and reason about tool outputs
#   :error_recovery      - Handle tool failures, retry, adapt
#   :constraint_following - Must use tool, must NOT use tool, format requirements
#   :tool_chaining       - Sequential dependencies, state across calls
#   :robustness          - Paraphrased instructions, distractors, noise

module Reliability
  module CapabilityTests
    # Test definition with capability tagging
    Test = Data.define(:name, :capability, :description, :setup, :task, :expect, :tags) do
      def initialize(name:, capability:, description:, setup:, task:, expect:, tags: [])
        super
      end
    end

    # All tests organized by capability
    TESTS = {
      # =========================================================================
      # BASIC REASONING - No tools, pure LLM capability
      # =========================================================================
      basic_reasoning: [
        Test.new(
          name: "arithmetic",
          capability: :basic_reasoning,
          description: "Simple arithmetic without tools",
          setup: ->(model) { Smolagents.agent.model { model }.build },
          task: "What is 2 + 2?",
          expect: "4"
        ),
        Test.new(
          name: "factual_recall",
          capability: :basic_reasoning,
          description: "Simple factual question",
          setup: ->(model) { Smolagents.agent.model { model }.build },
          task: "What is the capital of France?",
          expect: "Paris"
        ),
        Test.new(
          name: "logical_inference",
          capability: :basic_reasoning,
          description: "Basic logical deduction",
          setup: ->(model) { Smolagents.agent.model { model }.build },
          task: "If all cats are animals, and Whiskers is a cat, is Whiskers an animal? Answer yes or no.",
          expect: "yes"
        )
      ],

      # =========================================================================
      # TOOL INVOCATION - Single tool, correct parameters
      # =========================================================================
      tool_invocation: [
        Test.new(
          name: "single_tool_explicit",
          capability: :tool_invocation,
          description: "Use explicitly named tool",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:calculate, "Evaluate a math expression", expression: String) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval
              .build
          },
          task: "Use the calculate tool to compute 15 * 3",
          expect: "45"
        ),
        Test.new(
          name: "string_manipulation",
          capability: :tool_invocation,
          description: "Tool with string parameter",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:reverse, "Reverse a string", text: String) { |text:| text.reverse }
              .build
          },
          task: "Use the reverse tool to reverse the word 'hello'",
          expect: "olleh"
        ),
        Test.new(
          name: "search_tool",
          capability: :tool_invocation,
          description: "Tool that returns descriptive content",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:search, "Search for information", query: String) { |query:| "Found: #{query} is a programming language" }
              .build
          },
          task: "Search for information about Ruby",
          expect: "Ruby"
        )
      ],

      # =========================================================================
      # PARAMETER HANDLING - Multiple params, optional, types
      # =========================================================================
      parameter_handling: [
        Test.new(
          name: "two_required_params",
          capability: :parameter_handling,
          description: "Tool with two required parameters",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:repeat, "Repeat text N times", text: String, times: Integer) { |text:, times:| text * times }
              .build
          },
          task: "Use the repeat tool to repeat 'hi' 3 times",
          expect: "hihihi"
        ),
        Test.new(
          name: "optional_param_used",
          capability: :parameter_handling,
          description: "Tool with optional parameter - use it",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:greet, "Generate a greeting",
                    name: String,
                    formal: { type: "boolean", description: "Use formal greeting", nullable: true }) do |name:, formal: false|
                formal ? "Good day, #{name}." : "Hey #{name}!"
            end
              .build
          },
          task: "Greet Alice formally using the greet tool",
          expect: "Good day"
        ),
        Test.new(
          name: "optional_param_default",
          capability: :parameter_handling,
          description: "Tool with optional parameter - use default",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:greet, "Generate a greeting",
                    name: String,
                    formal: { type: "boolean", description: "Use formal greeting", nullable: true }) do |name:, formal: false|
                formal ? "Good day, #{name}." : "Hey #{name}!"
            end
              .build
          },
          task: "Greet Bob casually using the greet tool",
          expect: "Hey Bob"
        ),
        Test.new(
          name: "type_coercion",
          capability: :parameter_handling,
          description: "Integer parameter from string context",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:power, "Raise base to exponent", base: Integer, exponent: Integer) { |base:, exponent:| base**exponent }
              .build
          },
          task: "Use power to calculate two to the power of ten",
          expect: "1024"
        )
      ],

      # =========================================================================
      # TOOL SELECTION - Choose correct tool from multiple
      # =========================================================================
      tool_selection: [
        Test.new(
          name: "choose_among_three",
          capability: :tool_selection,
          description: "Select correct tool from three options",
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
        ),
        Test.new(
          name: "choose_by_description",
          capability: :tool_selection,
          description: "Select tool based on description match",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:word_count, "Count words in text", text: String) { |text:| text.split.size }
              .tool(:char_count, "Count characters in text", text: String) { |text:| text.length }
              .tool(:line_count, "Count lines in text", text: String) { |text:| text.lines.size }
              .build
          },
          task: "How many words are in 'The quick brown fox'?",
          expect: "4"
        )
      ],

      # =========================================================================
      # RESULT INTERPRETATION - Process and transform tool outputs
      # =========================================================================
      result_interpretation: [
        Test.new(
          name: "count_list_items",
          capability: :result_interpretation,
          description: "Get list from tool, count items",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_items, "Get a list of items") { %w[apple banana cherry] }
              .build
          },
          task: "Use get_items to get the list, then tell me how many items there are",
          expect: "3"
        ),
        Test.new(
          name: "transform_case",
          capability: :result_interpretation,
          description: "Get string from tool, transform it",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_name, "Get a name") { "alice" }
              .build
          },
          task: "Use get_name to get a name, then return it in uppercase",
          expect: "ALICE"
        ),
        Test.new(
          name: "extract_from_hash",
          capability: :result_interpretation,
          description: "Extract specific field from hash result",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              # Use string keys - models expect JSON-style access
              .tool(:get_user, "Get user info") { { "name" => "Bob", "age" => 30, "city" => "NYC" } }
              .build
          },
          task: "Use get_user and tell me the user's city",
          expect: "NYC"
        ),
        Test.new(
          name: "interpret_structured_return",
          capability: :result_interpretation,
          description: "Interpret class-based tool with structured output",
          setup: lambda { |model|
            require_relative "../../examples/tools/02_class_tools"
            Smolagents.agent.model { model }.tools(TemperatureConverter.new).build
          },
          task: "Convert 100 degrees Celsius to Fahrenheit using convert_temp",
          expect: "212"
        )
      ],

      # =========================================================================
      # CONSTRAINT FOLLOWING - Must/must not use tool, format requirements
      # =========================================================================
      constraint_following: [
        # Must use tool (can't guess the answer)
        Test.new(
          name: "must_use_tool_secret",
          capability: :constraint_following,
          description: "Answer is unknowable without tool",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_secret, "Get the secret number") { 73 }
              .build
          },
          task: "What is the secret number? Use the get_secret tool.",
          expect: "73",
          tags: [:must_use_tool]
        ),
        Test.new(
          name: "must_use_tool_lookup",
          capability: :constraint_following,
          description: "External data lookup required",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:lookup_user, "Look up a user's email by ID",
                    user_id: Integer, output_type: "string") { |user_id:| "user#{user_id}@example.com" }
              .build
          },
          task: "Look up the email for user ID 42 using the lookup_user tool",
          expect: "user42@example.com",
          tags: [:must_use_tool]
        ),
        Test.new(
          name: "explicit_tool_instruction",
          capability: :constraint_following,
          description: "Very explicit instruction to use tool",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:concat, "Concatenate two strings", a: String, b: String) { |a:, b:| "#{a}#{b}" }
              .build
          },
          task: "YOU MUST call the concat tool with a='Hello' and b='World'. Return the result.",
          expect: "HelloWorld",
          tags: [:must_use_tool]
        ),
        # Should NOT use tool (negative test)
        Test.new(
          name: "should_not_use_tool",
          capability: :constraint_following,
          description: "Tool available but unnecessary for trivial task",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:calculate, "Evaluate a math expression", expression: String) { |expression:| eval(expression).to_f } # rubocop:disable Security/Eval
              .build
          },
          task: "What is 1 + 1? Answer directly without using tools.",
          expect: "2",
          tags: [:should_not_use_tool]
        )
      ],

      # =========================================================================
      # ERROR RECOVERY - Handle failures, retry, adapt
      # =========================================================================
      error_recovery: [
        Test.new(
          name: "retry_after_error",
          capability: :error_recovery,
          description: "Tool fails once, agent retries in next step",
          setup: lambda { |model|
            call_count = [0] # Use array to maintain state across calls
            Smolagents.agent
              .model { model }
              .tool(:flaky_data, "Get data (may fail on first try)") do
                call_count[0] += 1
                raise "Connection timeout - please retry" if call_count[0] == 1

                "success_data_123"
              end
              .build
          },
          task: "Call flaky_data tool and return the data it returns. It may fail on first try, so retry if needed.",
          expect: "123",
          tags: [:error_handling]
        ),
        Test.new(
          name: "fallback_on_empty",
          capability: :error_recovery,
          description: "Handle nil result, try alternative",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              # Return nil (falsy) so ||= pattern works - testing basic fallback logic
              .tool(:primary_search, "Primary search - returns nil if no results") { nil }
              .tool(:backup_search, "Backup search - reliable fallback") { "Found: Ruby is great" }
              .build
          },
          task: "Search for info about Ruby. Use primary_search first, if nil use backup_search.",
          expect: "Ruby",
          tags: [:error_handling]
        ),
        Test.new(
          name: "detect_invalid_result",
          capability: :error_recovery,
          description: "Detect when result contains ERROR and try alternative",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_price, "Get price for item (returns ERROR if not found)", item: String) do |item:|
                item == "apple" ? "ERROR: item not found" : "$2.50"
              end
              .build
          },
          task: "Get the price for 'apple'. If the result contains 'ERROR', try 'banana' instead.",
          expect: "2.50",
          tags: [:error_handling]
        )
      ],

      # =========================================================================
      # TOOL CHAINING - Sequential dependencies
      # =========================================================================
      tool_chaining: [
        Test.new(
          name: "output_feeds_input",
          capability: :tool_chaining,
          description: "Use output of first tool as input to second",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_number, "Get a number") { 42 }
              .tool(:double, "Double a number", n: Integer) { |n:| n * 2 }
              .build
          },
          task: "Get a number, then double it",
          expect: "84"
        ),
        Test.new(
          name: "three_step_chain",
          capability: :tool_chaining,
          description: "Chain three tool calls",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:fetch_text, "Fetch text") { "hello world" }
              .tool(:uppercase, "Convert to uppercase", text: String) { |text:| text.upcase }
              .tool(:word_count, "Count words", text: String) { |text:| text.split.size }
              .build
          },
          task: "Fetch the text, convert it to uppercase, then count the words",
          expect: "2"
        )
      ],

      # =========================================================================
      # ROBUSTNESS - Paraphrased, distractors, edge cases
      # =========================================================================
      robustness: [
        Test.new(
          name: "paraphrased_instruction",
          capability: :robustness,
          description: "Same task, different wording",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:multiply, "Multiply two numbers", a: Integer, b: Integer) { |a:, b:| a * b }
              .build
          },
          task: "I need you to find the product of seven and eight using the multiplication function",
          expect: "56",
          tags: [:paraphrase]
        ),
        Test.new(
          name: "with_distractor_tools",
          capability: :robustness,
          description: "Correct tool among irrelevant options",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:weather, "Get weather") { "Sunny, 72F" }
              .tool(:stock_price, "Get stock price", symbol: String) { |symbol:| "$#{rand(100..500)}" }
              .tool(:reverse, "Reverse a string", text: String) { |text:| text.reverse }
              .tool(:translate, "Translate text", text: String, lang: String) { |text:, lang:| "#{text} (#{lang})" }
              .build
          },
          task: "Reverse the string 'robot'",
          expect: "tobor",
          tags: [:distractors]
        ),
        Test.new(
          name: "verbose_context",
          capability: :robustness,
          description: "Task buried in verbose instructions",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
              .build
          },
          task: "I've been thinking about this problem for a while and I really need your help. " \
                "What I'm trying to do is actually pretty simple when you think about it. " \
                "Could you please use the add tool to add 17 and 25? " \
                "It would really help me out. Thanks in advance!",
          expect: "42",
          tags: [:verbose]
        ),
        Test.new(
          name: "empty_string_param",
          capability: :robustness,
          description: "Handle empty string parameter",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:length, "Get string length", text: String) { |text:| text.length }
              .build
          },
          task: "What is the length of an empty string ''?",
          expect: "0",
          tags: [:edge_case]
        ),
        Test.new(
          name: "unicode_handling",
          capability: :robustness,
          description: "Handle unicode characters correctly",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:reverse, "Reverse a string", text: String) { |text:| text.reverse }
              .build
          },
          task: "Reverse the string 'café'",
          expect: "éfac",
          tags: [:edge_case]
        ),
        Test.new(
          name: "special_characters",
          capability: :robustness,
          description: "Handle special characters in parameters",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:echo, "Echo text back", text: String) { |text:| text }
              .build
          },
          task: "Use echo with the text: Hello \"World\" & <Friends>",
          expect: "Hello",
          tags: [:edge_case]
        )
      ],

      # =========================================================================
      # SELF-CORRECTION - Detect and fix mistakes
      # =========================================================================
      self_correction: [
        Test.new(
          name: "wrong_tool_then_correct",
          capability: :self_correction,
          description: "Realize wrong tool was used, use correct one",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
              .tool(:multiply, "Multiply two numbers", a: Integer, b: Integer) { |a:, b:| a * b }
              .build
          },
          task: "What is 5 multiplied by 6? Make sure you use multiplication, not addition.",
          expect: "30"
        ),
        Test.new(
          name: "verify_and_correct",
          capability: :self_correction,
          description: "Use feedback to find correct answer",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:validate, "Check if a code is correct - returns ACCESS GRANTED or ACCESS DENIED",
                    code: String) do |code:|
                code == "1234" ? "ACCESS GRANTED" : "ACCESS DENIED"
            end
              .tool(:get_code, "Get the secret access code") { "1234" }
              .build
          },
          task: "Get the secret code, then validate it. Return the validation result.",
          expect: "GRANTED",
          tags: [:multi_tool]
        )
      ],

      # =========================================================================
      # MULTI-STEP REASONING - Complex reasoning across steps
      # =========================================================================
      multi_step_reasoning: [
        Test.new(
          name: "conditional_branching",
          capability: :multi_step_reasoning,
          description: "Take different actions based on result",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:check_status, "Check system status") { "degraded" }
              .tool(:get_details, "Get detailed status") { "Memory usage: 95%, CPU: 20%" }
              .tool(:summarize, "Summarize findings", text: String) { |text:| "Summary: #{text}" }
              .build
          },
          task: "Check status. If it's 'healthy', summarize 'All systems normal'. " \
                "Otherwise, get_details and summarize those.",
          expect: "Memory"
        ),
        Test.new(
          name: "aggregate_results",
          capability: :multi_step_reasoning,
          description: "Combine results from multiple tools",
          setup: lambda { |model|
            Smolagents.agent
              .model { model }
              .tool(:get_price, "Get item price", item: String) do |item:|
                { "apple" => 1.50, "banana" => 0.75, "orange" => 2.00 }.fetch(item, 0)
              end
              .build
          },
          task: "Get the prices of apple and banana, then tell me their total cost",
          expect: "2.25"
        )
      ]
    }.freeze

    class << self
      def all
        TESTS.values.flatten
      end

      def by_capability(capability)
        TESTS.fetch(capability, [])
      end

      def by_tag(tag)
        all.select { |t| t.tags.include?(tag) }
      end

      def capabilities
        TESTS.keys
      end

      def names
        all.map(&:name)
      end

      def get(name)
        all.find { |t| t.name == name.to_s }
      end
    end
  end
end
