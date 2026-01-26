# Pre-defined solutions for dry-run testing.
# Each solution is Ruby code that should pass the test when executed.

module Reliability
  module TestSolutions
    # Maps test name to the correct Ruby code solution
    SOLUTIONS = {
      # =========================================================================
      # ARITHMETIC
      # =========================================================================
      "addition_simple" => "final_answer(answer: 2 + 2)",
      "multiplication_simple" => "final_answer(answer: 7 * 8)",
      "multi_step_arithmetic" => "final_answer(answer: (5 + 3) * 4)",
      "average_calculation" => "final_answer(answer: [10, 20, 30, 40, 50].sum / 5)",
      "percentage_calculation" => "final_answer(answer: 200 * 0.15)",
      "compound_calculation" => "final_answer(answer: (25 * 4) + (30 / 6) - 7)",
      "factorial" => "final_answer(answer: (1..5).reduce(:*))",
      "fibonacci" => <<~RUBY.strip,
        fib = [1, 1]
        8.times { fib << fib[-1] + fib[-2] }
        final_answer(answer: fib[9])
      RUBY

      # =========================================================================
      # STRING PROCESSING
      # =========================================================================
      "string_reverse" => 'final_answer(answer: "hello".reverse)',
      "string_uppercase" => 'final_answer(answer: "hello world".upcase)',
      "word_count" => 'final_answer(answer: "The quick brown fox jumps".split.size)',
      "string_replace" => 'final_answer(answer: "banana".gsub("a", "x"))',
      "extract_digits" => 'final_answer(answer: "a1b2c3d4".scan(/\d/).join)',
      "palindrome_check" => 'final_answer(answer: "racecar" == "racecar".reverse ? "yes" : "no")',
      "anagram_check" => 'final_answer(answer: "listen".chars.sort == "silent".chars.sort ? "yes" : "no")',
      "vowel_consonant_count" => <<~RUBY.strip,
        word = "programming"
        vowels = word.count("aeiou")
        consonants = word.length - vowels
        final_answer(answer: "\#{vowels} vowels, \#{consonants} consonants")
      RUBY

      # =========================================================================
      # COLLECTIONS
      # =========================================================================
      "array_sum" => "final_answer(answer: [1, 2, 3, 4, 5].sum)",
      "array_max" => "final_answer(answer: [3, 7, 2, 9, 4].max)",
      "filter_evens" => "final_answer(answer: [1,2,3,4,5,6,7,8].select(&:even?))",
      "array_unique" => "final_answer(answer: [1,2,2,3,3,3,4].uniq)",
      "hash_values_sum" => "final_answer(answer: {a: 10, b: 20, c: 30}.values.sum)",
      "nested_sum" => "final_answer(answer: [[1,2], [3,4], [5,6]].flatten.sum)",
      "group_by_parity" => "final_answer(answer: [1,2,3,4,5,6].select(&:even?).sum)",
      "hash_transform_complex" => "final_answer(answer: {x: 2, y: 3, z: 4}.values.map { |v| v ** 2 }.sum)",
      "frequency_count" => <<~RUBY.strip,
        freq = "banana".chars.tally
        most_common = freq.max_by { |_, v| v }.first
        final_answer(answer: most_common)
      RUBY

      # =========================================================================
      # TOOL USAGE
      # =========================================================================
      "single_tool_add" => '@result = add(a: 15, b: 27)
final_answer(answer: @result)',
      "single_tool_greet" => '@greeting = greet(name: "Bob")
final_answer(answer: @greeting)',
      "two_tool_chain" => <<~RUBY.strip,
        @product = multiply(a: 8, b: 7)
        @result = add(a: @product, b: 14)
        final_answer(answer: @result)
      RUBY
      "tool_with_decision" => <<~RUBY.strip,
        @sum = add(a: 100, b: 50)
        @result = @sum > 100 ? subtract(a: @sum, b: 25) : @sum
        final_answer(answer: @result)
      RUBY
      "store_and_retrieve" => <<~RUBY.strip,
        store(key: "answer", value: "42")
        @val = retrieve(key: "answer")
        @result = add(a: @val.to_i, b: 8)
        final_answer(answer: @result)
      RUBY
      "multi_tool_calculation" => <<~RUBY.strip,
        @step1 = add(a: 10, b: 5)
        @step2 = multiply(a: @step1, b: 4)
        @result = divide(a: @step2, b: 3)
        final_answer(answer: @result.to_i)
      RUBY
      "conditional_tool_use" => <<~RUBY.strip,
        @div_result = divide(a: 100, b: 4)
        @result = @div_result > 20 ? multiply(a: @div_result.to_i, b: 2) : add(a: @div_result.to_i, b: 10)
        final_answer(answer: @result)
      RUBY
      "iterative_tool_use" => <<~RUBY.strip,
        @result = 1
        3.times { @result = multiply(a: @result, b: 2) }
        final_answer(answer: @result)
      RUBY

      # =========================================================================
      # CODE GENERATION
      # =========================================================================
      "simple_expression" => "final_answer(answer: 3 ** 4)",
      "simple_conditional" => 'final_answer(answer: 10 > 5 ? "yes" : "no")',
      "define_simple_method" => <<~RUBY.strip,
        def double(n)
          n * 2
        end
        final_answer(answer: double(21))
      RUBY
      "loop_sum" => "final_answer(answer: (1..10).sum)",
      "array_transformation" => "final_answer(answer: [1,2,3,4,5].map { |x| x * 2 }.sum)",
      "recursive_method" => <<~RUBY.strip,
        def factorial(n)
          n <= 1 ? 1 : n * factorial(n - 1)
        end
        final_answer(answer: factorial(6))
      RUBY
      "class_with_state" => <<~RUBY.strip,
        class Counter
          def initialize = @count = 0
          def increment = @count += 1
          def count = @count
        end
        c = Counter.new
        5.times { c.increment }
        final_answer(answer: c.count)
      RUBY
      "custom_sort" => <<~RUBY.strip,
        data = [{name: 'b', age: 30}, {name: 'a', age: 25}]
        sorted = data.sort_by { |h| h[:age] }
        final_answer(answer: sorted.first[:name])
      RUBY
      "prime_check" => <<~RUBY.strip,
        def prime?(n)
          return false if n < 2
          (2..Math.sqrt(n)).none? { |i| n % i == 0 }
        end
        final_answer(answer: prime?(17) ? "prime" : "not prime")
      RUBY

      # =========================================================================
      # FORMAT COMPLIANCE
      # =========================================================================
      "single_word" => 'final_answer(answer: "blue")',
      "yes_no_answer" => 'final_answer(answer: "yes")',
      "comma_separated" => 'final_answer(answer: "2, 3, 5, 7, 11")',
      "key_value_format" => 'final_answer(answer: "name=Alice, age=30")',
      "numbered_list" => 'final_answer(answer: "Item 1\nItem 2\nItem 3")',
      "json_simple" => 'final_answer(answer: \'{"status": "ok"}\')',
      "json_with_number" => 'final_answer(answer: \'{"count": 42, "valid": true}\')',
      "markdown_table" => 'final_answer(answer: "| Name | Age |\n|------|-----|\n| Alice | 30 |")',
      "multiline_string" => 'final_answer(answer: "one\ntwo\nthree")',

      # =========================================================================
      # CONCEPTUAL
      # =========================================================================
      "code_reading" => "final_answer(answer: [1,2,3].map { |x| x * 2 })",
      "simple_explanation" => <<~RUBY.strip,
        final_answer(answer: "The .reverse method returns a new string with characters in reverse order.")
      RUBY
      "error_identification" => <<~RUBY.strip,
        final_answer(answer: "Ruby does not have a .fifth method. Use arr[4] or arr.fetch(4) instead.")
      RUBY
      "dsl_reading" => 'final_answer(answer: "It configures the model and the tools (search).")',
      "pattern_recognition" => 'final_answer(answer: "Each number is doubled. Next is 64.")',
      "agent_explanation" => <<~RUBY.strip,
        final_answer(answer: "An AI agent can take autonomous actions using tools, " \
                     "while a chatbot only responds to messages. " \
                     "Agents can execute code, call APIs, and iterate on tasks.")
      RUBY
      "refactoring_suggestion" => 'final_answer(answer: "Use a ternary: x ? \'yes\' : \'no\'")',
      "api_design" => 'final_answer(answer: "def search_users(name:, limit: 10)")',
      "dsl_design" => 'final_answer(answer: "Smolagents.tool(:weather).inputs(city: String).build")'
    }.freeze

    # Inject solutions into test definitions
    def self.inject_solutions!
      TestDefinitions.all_tests.each do |test|
        solution = SOLUTIONS[test[:name]]
        test[:solution] = solution if solution
      end
    end
  end
end
