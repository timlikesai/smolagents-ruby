require_relative "agent/tool_formatting"

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

        class << self
          include ToolFormatting

          def generate(tools:, team: nil, authorized_imports: nil, custom: nil)
            [
              INTRO,
              tools_section(tools),
              EXAMPLES,
              team_section(team),
              imports_section(authorized_imports),
              Templates::TOOL_OUTPUT_SECURITY,
              RULES,
              tool_usage_section(tools),
              custom
            ].compact.join("\n\n")
          end

          private

          def tools_section(tools)
            return nil unless tools&.any?

            formatted = tools.map { |tool| format_tool(tool) }
            ["TOOLS AVAILABLE:", *formatted].join("\n\n")
          end

          def team_section(team)
            Formatting.build_section("TEAM MEMBERS (call like tools):",
                                     Formatting.format_team_members(team))
          end

          def imports_section(imports) = imports&.any? ? "ALLOWED REQUIRES: #{imports.join(", ")}" : nil

          def tool_usage_section(tools)
            return nil unless tools&.any?

            # Generate tool-specific usage hints
            hints = tools.take(3).filter_map { |tool| tool_usage_hint(tool) }
            return TOOL_USAGE if hints.empty?

            "#{TOOL_USAGE}\n#{hints.join("\n")}"
          end

          def tool_usage_hint(tool)
            return nil unless tool.respond_to?(:name) && tool.respond_to?(:description)

            desc = tool.description.to_s.downcase
            name = tool.name.to_s

            # Generate contextual hints based on tool description
            if desc.include?("returns hash") || desc.include?("returns a hash")
              "# #{name} returns a hash - access values: result = #{name}(...); result[\"key\"]"
            elsif desc.include?("returns array") || desc.include?("returns a list")
              "# #{name} returns an array - iterate: #{name}(...).each { |item| item[\"key\"] }"
            end
          end
        end
      end
    end
  end
end
