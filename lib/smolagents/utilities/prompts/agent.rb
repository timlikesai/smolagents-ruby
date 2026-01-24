module Smolagents
  module Utilities
    module Prompts
      # Agent prompt generator - all agents think in Ruby code.
      #
      # Generates system prompts that instruct models to write Ruby code blocks
      # using tools as method calls with keyword arguments.
      #
      # @example Generate an agent prompt
      #   prompt = Agent.generate(tools: [search, calculator])
      module Agent
        INTRO = <<~PROMPT.freeze
          You solve tasks by writing Ruby code. Respond with a ```ruby code block.

          ```ruby
          # Reasoning as comments
          @data = search(query: "Ruby tutorials")  # Instance vars persist between blocks
          best = @data.first                       # Access in same or later blocks
          final_answer(answer: best['title'])      # Return your answer
          ```

          PATTERN:
          1. Call tools and store results: `@results = search(...)`
          2. Process/combine the results
          3. Call final_answer with your answer

          IMPORTANT:
          - Instance vars persist: `@results = search(...)` (available in next code block)
          - Local vars: `results = ...` are lost between code blocks
          - Multiple tool calls are batched automatically for speed
          - STOP after closing ``` marks
        PROMPT

        EXAMPLES = <<~PROMPT.freeze
          EXAMPLES:
          ---
          Task: "Find beginner Ruby tutorials and recommend the best one"

          ```ruby
          # Instance vars persist between code blocks
          @tutorials = search(query: "beginner Ruby tutorials")

          # Access persisted results
          best = @tutorials.first
          final_answer(answer: "I recommend: \#{best['title']} - \#{best['link']}")
          ```

          ---
          Task: "Compare Ruby and Python popularity"

          ```ruby
          # Multiple tool calls - they run in parallel automatically
          @ruby_info = search(query: "Ruby programming popularity 2026")
          @python_info = search(query: "Python programming popularity 2026")

          # Process persisted results
          comparison = "Ruby: \#{@ruby_info.first['description']}\\n"
          comparison += "Python: \#{@python_info.first['description']}"
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

        RULES = <<~PROMPT.freeze
          RULES:
          1. Output ONLY a ```ruby code block (# comments for reasoning)
          2. Store tool results: `@data = tool(arg: value)` (persists)
          3. Access stored vars: `@data.first`, `@data.map {...}`
          4. End with final_answer(answer: your_result)
          5. STOP after closing ```
        PROMPT

        class << self
          def generate(tools:, team: nil, authorized_imports: nil, custom: nil)
            [
              INTRO,
              tools_section(tools),
              EXAMPLES,
              team_section(team),
              imports_section(authorized_imports),
              Templates::TOOL_OUTPUT_SECURITY,
              RULES,
              custom
            ].compact.join("\n\n")
          end

          private

          def tools_section(tools)
            return nil unless tools&.any?

            formatted = tools.map { |tool| format_tool(tool) }
            ["TOOLS AVAILABLE:", *formatted].join("\n\n")
          end

          def format_tool(tool)
            return "- #{tool}" if tool.is_a?(String)

            signature = build_signature(tool)
            example = build_example(tool)
            "- #{signature} - #{tool.description}\n  Example: #{example}"
          end

          def build_signature(tool)
            inputs = tool.inputs || {}
            params = inputs.map { |n, spec| format_param_signature(n, spec) }
            params.empty? ? "#{tool.name}()" : "#{tool.name}(#{params.join(", ")})"
          end

          def format_param_signature(name, spec)
            type = spec[:type] || spec["type"]
            type_str = spec[:nullable] || spec["nullable"] ? "#{type}?" : type.to_s
            "#{name}: #{type_str}"
          end

          def build_example(tool)
            inputs = tool.inputs || {}
            args = inputs.map { |n, spec| format_example_arg(n, spec) }
            args.empty? ? "#{tool.name}()" : "#{tool.name}(#{args.join(", ")})"
          end

          def format_example_arg(name, spec)
            type = spec[:type] || spec["type"]
            "#{name}: #{Templates.example_for_type(type, spec[:description] || spec["description"] || "").inspect}"
          end

          def team_section(team)
            Formatting.build_section("TEAM MEMBERS (call like tools):",
                                     Formatting.format_team_members(team))
          end

          def imports_section(imports) = imports&.any? ? "ALLOWED REQUIRES: #{imports.join(", ")}" : nil
        end
      end
    end
  end
end
