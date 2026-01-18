module Smolagents
  module Utilities
    module Prompts
      module CodeAgent
        # Multi-step examples showing Ruby code block patterns.
        EXAMPLES = <<~PROMPT.freeze
          EXAMPLES:
          ---
          Task: "What is 25 times 4, then double it?"

          ```ruby
          # Calculate step by step - tool results support arithmetic
          result = calculate(expression: "25 * 4")
          final_result = result * 2
          final_answer(answer: final_result)
          ```

          ---
          Task: "Find the population of Tokyo and divide it by 1000."

          ```ruby
          # Search for current data, then calculate
          data = web_search(query: "Tokyo population 2026")
          puts data  # See what we got
          ```
          Observation:
          <tool_output>
          Tokyo has approximately 14 million people.
          </tool_output>

          ```ruby
          # Now do the division
          population = 14_000_000
          final_answer(answer: population / 1000)
          ```

          ---
          Task: "What is the current weather in Paris?"

          ```ruby
          # Search and return directly
          weather = web_search(query: "current weather Paris")
          final_answer(answer: weather)
          ```
        PROMPT
      end
    end
  end
end
