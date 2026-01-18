require_relative "code_agent_examples"

module Smolagents
  module Utilities
    module Prompts
      # Agent prompt - agents think and act in Ruby code.
      #
      # @example Generate an agent prompt
      #   prompt = CodeAgent.generate(tools: [search, wikipedia], custom: "Be thorough")
      module CodeAgent
        INTRO = <<~PROMPT.freeze
          You solve tasks by writing Ruby code. Respond with a ```ruby code block.

          ```ruby
          # Reasoning as comments
          data = search(query: "Ruby tutorials")  # Assign tool results to variables
          best = data.first                       # Work with the results
          final_answer(answer: best['title'])     # Return your answer
          ```

          PATTERN:
          1. Call tools and assign results to variables
          2. Process/combine the results
          3. Call final_answer with your answer

          IMPORTANT:
          - Assign tool results to variables: `results = search(...)`
          - Work with results AFTER assignment: `results.first`, `results.map {...}`
          - Multiple tool calls are batched automatically for speed
          - STOP after closing ``` marks
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Output ONLY a ```ruby code block (# comments for reasoning)
          2. Assign tool results to variables: `data = tool(arg: value)`
          3. Process results after assignment
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

            formatted = tools.map { |doc| format_tool(doc) }
            ["TOOLS AVAILABLE:", *formatted].join("\n\n")
          end

          def format_tool(tool_doc)
            lines = tool_doc.split("\n")
            name_desc = lines.first.split(": ", 2)
            name = name_desc.first
            description = name_desc.last

            inputs_line = lines.find { |l| l.include?("Takes inputs:") }
            args = inputs_line&.scan(/(\w+): \{type:/)&.flatten || []

            call_example = args.empty? ? "#{name}()" : "#{name}(#{args.first}: \"...\")"
            "- #{name}(#{args.map { |a| "#{a}:" }.join(", ")}): #{description}\n  Example: #{call_example}"
          end

          def team_section(team)
            members = Formatting.format_team_members(team)
            Formatting.build_section("TEAM MEMBERS (call like tools):", members)
          end

          def imports_section(authorized_imports)
            return nil unless authorized_imports&.any?

            "ALLOWED REQUIRES: #{authorized_imports.join(", ")}"
          end
        end
      end
    end
  end
end
