module Smolagents
  module Utilities
    module Prompts
      module CodeAgent
        # Examples showing the assign-then-process pattern.
        EXAMPLES = <<~PROMPT.freeze
          EXAMPLES:
          ---
          Task: "Find beginner Ruby tutorials and recommend the best one"

          ```ruby
          # Assign search results to a variable
          tutorials = search(query: "beginner Ruby tutorials")

          # Work with the results
          best = tutorials.first
          final_answer(answer: "I recommend: \#{best['title']} - \#{best['link']}")
          ```

          ---
          Task: "Compare Ruby and Python popularity"

          ```ruby
          # Multiple tool calls - they run in parallel automatically
          ruby_info = search(query: "Ruby programming popularity 2026")
          python_info = search(query: "Python programming popularity 2026")

          # Process both results
          comparison = "Ruby: \#{ruby_info.first['description']}\\n"
          comparison += "Python: \#{python_info.first['description']}"
          final_answer(answer: comparison)
          ```

          ---
          Task: "What is 25 * 4, doubled?"

          ```ruby
          # Tool results support arithmetic
          result = calculate(expression: "25 * 4")
          final_answer(answer: result * 2)
          ```
        PROMPT
      end
    end
  end
end
