# Test definitions organized by capability dimension.
# Each dimension has tests of increasing difficulty to find capability ceilings.

module Reliability
  module TestDefinitions
    @store = {}

    class << self
      attr_accessor :store
    end

    # Built-in tools for tool-based tests
    # IMPORTANT: Must include :inputs with type specs so InlineTool shows proper signatures
    TOOLS = {
      add: {
        desc: "Add two numbers",
        inputs: { a: Integer, b: Integer },
        impl: ->(a:, b:) { a + b }
      },
      subtract: {
        desc: "Subtract b from a",
        inputs: { a: Integer, b: Integer },
        impl: ->(a:, b:) { a - b }
      },
      multiply: {
        desc: "Multiply two numbers",
        inputs: { a: Integer, b: Integer },
        impl: ->(a:, b:) { a * b }
      },
      divide: {
        desc: "Divide a by b",
        inputs: { a: Integer, b: Integer },
        impl: ->(a:, b:) { a.to_f / b }
      },
      greet: {
        desc: "Greet a person by name",
        inputs: { name: String },
        impl: ->(name:) { "Hello, #{name}!" }
      },
      lookup: {
        desc: "Look up a fact about a topic",
        inputs: { topic: String },
        impl: ->(topic:) { "#{topic} is interesting" }
      },
      store: {
        desc: "Store a value with a key",
        inputs: { key: String, value: String },
        impl: lambda { |key:, value:|
          TestDefinitions.store[key] = value
          "stored"
        }
      },
      retrieve: {
        desc: "Retrieve a value by key",
        inputs: { key: String },
        impl: ->(key:) { TestDefinitions.store[key] || "not found" }
      }
    }.freeze

    # =========================================================================
    # ARITHMETIC - Numerical computation
    # =========================================================================
    ARITHMETIC = [
      # Easy
      {
        name: "addition_simple",
        task: "What is 2 + 2? Just the number.",
        expect: "4",
        difficulty: :easy
      },
      {
        name: "multiplication_simple",
        task: "Calculate 7 * 8.",
        expect: "56",
        difficulty: :easy
      },
      # Medium
      {
        name: "multi_step_arithmetic",
        task: "Add 5 and 3, then multiply that result by 4.",
        expect: "32",
        difficulty: :medium
      },
      {
        name: "average_calculation",
        task: "Calculate the average of [10, 20, 30, 40, 50].",
        expect: "30",
        difficulty: :medium
      },
      {
        name: "percentage_calculation",
        task: "What is 15% of 200?",
        expect: "30",
        difficulty: :medium
      },
      # Hard
      {
        name: "compound_calculation",
        task: "Calculate (25 * 4) + (30 / 6) - 7.",
        expect: "98",
        difficulty: :hard
      },
      {
        name: "factorial",
        task: "Calculate 5! (5 factorial).",
        expect: "120",
        difficulty: :hard
      },
      {
        name: "fibonacci",
        task: "What is the 10th Fibonacci number? (1,1,2,3,5,8,13,21,34,?)",
        expect: "55",
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # STRING PROCESSING - Text manipulation
    # =========================================================================
    STRING_PROCESSING = [
      # Easy
      {
        name: "string_reverse",
        task: "Reverse the string 'hello'.",
        expect: "olleh",
        difficulty: :easy
      },
      {
        name: "string_uppercase",
        task: "Convert 'hello world' to uppercase.",
        expect: "HELLO WORLD",
        difficulty: :easy
      },
      # Medium
      {
        name: "word_count",
        task: "Count the number of words in 'The quick brown fox jumps'.",
        expect: "5",
        difficulty: :medium
      },
      {
        name: "string_replace",
        task: "Replace all 'a' with 'x' in 'banana'.",
        expect: "bxnxnx",
        difficulty: :medium
      },
      {
        name: "extract_digits",
        task: "Extract all digits from 'a1b2c3d4' and return them as a string.",
        expect: "1234",
        difficulty: :medium
      },
      # Hard
      {
        name: "palindrome_check",
        task: "Is 'racecar' a palindrome? Answer yes or no.",
        expect: "yes",
        difficulty: :hard
      },
      {
        name: "anagram_check",
        task: "Are 'listen' and 'silent' anagrams? Answer yes or no.",
        expect: "yes",
        difficulty: :hard
      },
      {
        name: "vowel_consonant_count",
        task: "In the word 'programming', how many vowels and consonants? Format: 'X vowels, Y consonants'",
        check: ->(o) { o.include?("3") && o.include?("8") },
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # COLLECTIONS - Array and hash operations
    # =========================================================================
    COLLECTIONS = [
      # Easy
      {
        name: "array_sum",
        task: "Sum the array [1, 2, 3, 4, 5].",
        expect: "15",
        difficulty: :easy
      },
      {
        name: "array_max",
        task: "Find the maximum value in [3, 7, 2, 9, 4].",
        expect: "9",
        difficulty: :easy
      },
      # Medium
      {
        name: "filter_evens",
        task: "From [1,2,3,4,5,6,7,8], return only the even numbers.",
        check: ->(o) { %w[2 4 6 8].all? { |n| o.include?(n) } && !o.include?("1") },
        difficulty: :medium
      },
      {
        name: "array_unique",
        task: "Remove duplicates from [1,2,2,3,3,3,4] and return the unique values.",
        check: ->(o) { o.include?("1") && o.include?("2") && o.include?("3") && o.include?("4") },
        difficulty: :medium
      },
      {
        name: "hash_values_sum",
        task: "Given {a: 10, b: 20, c: 30}, sum all the values.",
        expect: "60",
        difficulty: :medium
      },
      # Hard
      {
        name: "nested_sum",
        task: "Sum all numbers in this nested structure: [[1,2], [3,4], [5,6]].",
        expect: "21",
        difficulty: :hard
      },
      {
        name: "group_by_parity",
        task: "Group [1,2,3,4,5,6] into evens and odds. Return the sum of evens.",
        expect: "12",
        difficulty: :hard
      },
      {
        name: "hash_transform_complex",
        task: "Given {x: 2, y: 3, z: 4}, square each value and return their sum.",
        expect: "29",
        difficulty: :hard
      },
      {
        name: "frequency_count",
        task: "Count how many times each letter appears in 'banana'. What letter appears most?",
        expect: "a",
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # TOOL USAGE - Using provided tools correctly
    # =========================================================================
    TOOL_USAGE = [
      # Easy
      {
        name: "single_tool_add",
        task: "Use the add tool to add 15 and 27.",
        tools: [:add],
        expect: "42",
        difficulty: :easy
      },
      {
        name: "single_tool_greet",
        task: "Use the greet tool to greet 'Bob'.",
        tools: [:greet],
        expect: "Bob",
        difficulty: :easy
      },
      # Medium
      {
        name: "two_tool_chain",
        task: "Multiply 8 by 7, then add 14 to the result.",
        tools: %i[multiply add],
        expect: "70",
        difficulty: :medium
      },
      {
        name: "tool_with_decision",
        task: "Add 100 and 50. If the result is greater than 100, subtract 25 from it.",
        tools: %i[add subtract],
        expect: "125",
        difficulty: :medium
      },
      {
        name: "store_and_retrieve",
        task: "Store the value 42 with key 'answer', then retrieve it and add 8.",
        tools: %i[store retrieve add],
        expect: "50",
        difficulty: :medium
      },
      # Hard
      {
        name: "multi_tool_calculation",
        task: "Calculate ((10 + 5) * 4) / 3 using the appropriate tools.",
        tools: %i[add multiply divide],
        expect: "20",
        difficulty: :hard
      },
      {
        name: "conditional_tool_use",
        task: "Divide 100 by 4. If result > 20, multiply by 2, otherwise add 10.",
        tools: %i[divide multiply add],
        expect: "50",
        difficulty: :hard
      },
      {
        name: "iterative_tool_use",
        task: "Starting with 1, multiply by 2 three times. What's the final result?",
        tools: [:multiply],
        expect: "8",
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # CODE GENERATION - Producing and executing code
    # =========================================================================
    CODE_GENERATION = [
      # Easy
      {
        name: "simple_expression",
        task: "Write Ruby code to calculate 3 ** 4 (3 to the power of 4).",
        expect: "81",
        difficulty: :easy
      },
      {
        name: "simple_conditional",
        task: "If 10 > 5, return 'yes', otherwise return 'no'.",
        expect: "yes",
        difficulty: :easy
      },
      # Medium
      {
        name: "define_simple_method",
        task: "Define a method double(n) that returns n*2, then call double(21).",
        expect: "42",
        difficulty: :medium
      },
      {
        name: "loop_sum",
        task: "Use a loop to sum numbers from 1 to 10.",
        expect: "55",
        difficulty: :medium
      },
      {
        name: "array_transformation",
        task: "Take [1,2,3,4,5], double each element, then sum them all.",
        expect: "30",
        difficulty: :medium
      },
      # Hard
      {
        name: "recursive_method",
        task: "Write a recursive method to calculate factorial of 6.",
        expect: "720",
        difficulty: :hard
      },
      {
        name: "class_with_state",
        task: "Define a Counter class with increment method. Create instance, increment 5 times, return count.",
        expect: "5",
        difficulty: :hard
      },
      {
        name: "custom_sort",
        task: "Sort [{name: 'b', age: 30}, {name: 'a', age: 25}] by age ascending. Return the first name.",
        expect: "a",
        difficulty: :hard
      },
      {
        name: "prime_check",
        task: "Write code to check if 17 is prime. Return 'prime' or 'not prime'.",
        expect: "prime",
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # FORMAT COMPLIANCE - Exact output formatting
    # =========================================================================
    FORMAT_COMPLIANCE = [
      # Easy
      {
        name: "single_word",
        task: "What color is the sky on a clear day? One word only.",
        expect: "blue",
        difficulty: :easy
      },
      {
        name: "yes_no_answer",
        task: "Is 7 greater than 3? Answer only 'yes' or 'no'.",
        expect: "yes",
        difficulty: :easy
      },
      # Medium
      {
        name: "comma_separated",
        task: "List the first 5 prime numbers, comma-separated.",
        check: ->(o) { %w[2 3 5 7 11].all? { |n| o.include?(n) } },
        difficulty: :medium
      },
      {
        name: "key_value_format",
        task: "Output: name=Alice, age=30 (exact format)",
        check: ->(o) { o.include?("name=Alice") && o.include?("age=30") },
        difficulty: :medium
      },
      {
        name: "numbered_list",
        task: "List numbers 1-3, each on its own line, prefixed with 'Item '",
        check: ->(o) { o.include?("Item 1") && o.include?("Item 2") && o.include?("Item 3") },
        difficulty: :medium
      },
      # Hard
      {
        name: "json_simple",
        task: 'Return exactly: {"status": "ok"}',
        check: ->(o) { o.include?('"status"') && o.include?('"ok"') },
        difficulty: :hard
      },
      {
        name: "json_with_number",
        task: 'Return exactly: {"count": 42, "valid": true}',
        check: ->(o) { o.include?('"count"') && o.include?("42") && o.include?('"valid"') && o.include?("true") },
        difficulty: :hard
      },
      {
        name: "markdown_table",
        task: "Create a markdown table with headers: Name, Age. One row: Alice, 30.",
        check: ->(o) { o.include?("|") && o.include?("Name") && o.include?("Alice") && o.include?("30") },
        difficulty: :hard
      },
      {
        name: "multiline_string",
        task: "Return a string with exactly 3 lines: 'one', 'two', 'three' (each on its own line).",
        check: ->(o) { o.include?("one") && o.include?("two") && o.include?("three") },
        difficulty: :hard
      }
    ].freeze

    # =========================================================================
    # CONCEPTUAL - Meta-level understanding and reasoning
    # =========================================================================
    CONCEPTUAL = [
      # Easy
      {
        name: "code_reading",
        task: "What does [1,2,3].map { |x| x * 2 } return?",
        check: ->(o) { o.include?("2") && o.include?("4") && o.include?("6") },
        difficulty: :easy
      },
      {
        name: "simple_explanation",
        task: "In one sentence, what does the Ruby method .reverse do to a string?",
        check: lambda { |o|
          o.downcase.include?("reverse") || o.downcase.include?("backward") || o.downcase.include?("order")
        },
        difficulty: :easy
      },
      # Medium
      {
        name: "error_identification",
        task: "What's wrong with: arr = [1,2,3]; arr.fifth? (Ruby has no .fifth method)",
        check: lambda { |o|
          words = %w[no not undefined doesn't]
          words.any? { |w| o.downcase.include?(w) }
        },
        difficulty: :medium
      },
      {
        name: "dsl_reading",
        task: "This DSL: .model { m }.tools(:search).build - what two things does it configure?",
        check: ->(o) { o.downcase.include?("model") && (o.downcase.include?("tool") || o.downcase.include?("search")) },
        difficulty: :medium
      },
      {
        name: "pattern_recognition",
        task: "Given the sequence 2,4,8,16,32 - what's the pattern and what comes next?",
        check: ->(o) { o.include?("64") },
        difficulty: :medium
      },
      # Hard
      {
        name: "agent_explanation",
        task: "Explain in 2-3 sentences: What is an AI agent and how does it differ from a simple chatbot?",
        check: lambda { |o|
          keywords = %w[tool action autonomous]
          o.length > 80 && keywords.any? { |k| o.downcase.include?(k) }
        },
        difficulty: :hard
      },
      {
        name: "refactoring_suggestion",
        task: "How would you improve: if x == true then 'yes' else 'no' end?",
        check: lambda { |o|
          o.include?("x ?") || o.include?("x?") || o.downcase.include?("ternary") || o.downcase.include?("simpl")
        },
        difficulty: :hard
      },
      {
        name: "api_design",
        task: "Design a simple Ruby method signature for searching users by name. Just the def line.",
        check: lambda { |o|
          has_def = o.include?("def")
          has_search = o.downcase.include?("search") || o.downcase.include?("find")
          has_def && has_search && o.downcase.include?("name")
        },
        difficulty: :hard
      },
      {
        name: "dsl_design",
        task: "Write a one-line DSL example for creating a tool that fetches weather. Use method chaining.",
        check: ->(o) { o.include?(".") && (o.downcase.include?("weather") || o.downcase.include?("tool")) },
        difficulty: :hard
      }
    ].freeze

    # All dimensions with metadata
    DIMENSIONS = {
      arithmetic: { name: "Arithmetic", tests: ARITHMETIC },
      string_processing: { name: "String Processing", tests: STRING_PROCESSING },
      collections: { name: "Collections", tests: COLLECTIONS },
      tool_usage: { name: "Tool Usage", tests: TOOL_USAGE },
      code_generation: { name: "Code Generation", tests: CODE_GENERATION },
      format_compliance: { name: "Format Compliance", tests: FORMAT_COMPLIANCE },
      conceptual: { name: "Conceptual", tests: CONCEPTUAL }
    }.freeze

    def self.for_dimension(dim)
      DIMENSIONS[dim.to_sym]&.fetch(:tests, []) || []
    end

    def self.all_tests
      DIMENSIONS.values.flat_map { |d| d[:tests] }
    end

    def self.dimension_names
      DIMENSIONS.keys
    end

    def self.by_difficulty(dim, difficulty)
      for_dimension(dim).select { |t| t[:difficulty] == difficulty }
    end

    def self.test_count
      all_tests.size
    end
  end
end
