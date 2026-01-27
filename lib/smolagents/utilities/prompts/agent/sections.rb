# Frozen prompt sections for agent system prompts.

module Smolagents
  module Utilities
    module Prompts
      module Agent
        # Static prompt sections - separated for maintainability.
        # Named "Sections" to avoid shadowing Prompts::Templates which has example_for_type.
        module Sections
          INTRO = <<~PROMPT.freeze
            You solve tasks by writing Ruby code. Respond with a ```ruby code block.

            ```ruby
            # Reasoning as comments
            @data = search(query: "Ruby tutorials")  # Instance vars persist between blocks
            best = @data.first                       # Access in same or later blocks
            final_answer(answer: best["title"])      # Return your answer
            ```

            PATTERN:
            1. Call tools and store results: `@results = search(...)`
            2. Process/combine the results
            3. Call final_answer with your answer

            IMPORTANT:
            - Instance vars persist: `@results = search(...)` (available in next code block)
            - Local vars: `results = ...` are lost between code blocks
            - Tool results are hashes with string keys: use `result["key"]` or `result[:key]` (both work)
            - Multiple tool calls in one block run in parallel automatically
            - STOP after closing ``` marks
          PROMPT

          EXAMPLES = <<~PROMPT.freeze
            EXAMPLES:
            ---
            Task: "Find beginner Ruby tutorials and recommend the best one"

            ```ruby
            # Instance vars persist between code blocks
            @tutorials = search(query: "beginner Ruby tutorials")

            # Access hash results - both string and symbol keys work
            best = @tutorials.first
            final_answer(answer: "I recommend: \#{best["title"]} - \#{best["link"]}")
            ```

            ---
            Task: "Compare Ruby and Python popularity"

            ```ruby
            # Multiple tool calls in one block run in parallel
            @ruby_info = search(query: "Ruby programming popularity 2026")
            @python_info = search(query: "Python programming popularity 2026")

            # Process results - use string keys for hash access
            comparison = "Ruby: \#{@ruby_info.first["description"]}\\n"
            comparison += "Python: \#{@python_info.first["description"]}"
            final_answer(answer: comparison)
            ```

            ---
            Task: "What is 25 * 4, doubled?"

            ```ruby
            # Tool results support arithmetic
            @result = calculate(expression: "25 * 4")
            final_answer(answer: @result * 2)
            ```
          PROMPT

          TOOL_USAGE = <<~PROMPT.freeze
            TOOL USAGE:
            - Tool results are hashes: access with `result["key"]` or `result[:key]`
            - Check for errors: `if result["error"]` or `if result.key?(:error)`
            - Iterate arrays: `results.each { |item| item["name"] }`
            - Extract values: `result["budget"]` not `result` when you need the number
          PROMPT

          RULES = <<~PROMPT.freeze
            RULES:
            1. Output ONLY a ```ruby code block (# comments for reasoning)
            2. Store tool results: `@data = tool(arg: value)` (persists)
            3. Access stored vars: `@data.first`, `@data["key"]`
            4. End with final_answer(answer: your_result)
            5. STOP after closing ```
          PROMPT

          HELPERS = <<~PROMPT.freeze
            DEBUG HELPERS (if stuck):
            - `puts inspect_state` - see all stored @variables with their values
            - `puts vars` - list variable names
            - `puts help` - list available tools
          PROMPT
        end
      end
    end
  end
end
