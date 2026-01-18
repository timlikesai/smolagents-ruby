require_relative "code_agent_examples"

module Smolagents
  module Utilities
    module Prompts
      # Code agent prompt - extends base with code block format.
      #
      # @example Generate a code agent prompt
      #   prompt = CodeAgent.generate(tools: [interpreter], custom: "Show your work")
      module CodeAgent
        INTRO = <<~PROMPT.freeze
          You are an expert assistant who solves tasks using Ruby code.
          Respond with a ```ruby code block. Use comments for reasoning.

          ```ruby
          # Your reasoning as comments
          result = tool_name(arg: value)
          final_answer(answer: result)
          ```

          IMPORTANT:
          - Write ONLY Ruby code in the code block (comments are fine)
          - End with final_answer(answer: result) when done
          - Tool results support arithmetic: result * 2, result + 10
          - Use puts(budget) to see step budget (remaining steps)
          - When low on steps, call final_answer immediately
          - STOP after closing ``` marks
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Output ONLY a ```ruby code block (use # comments for reasoning)
          2. Use keyword arguments: tool_name(arg: value)
          3. Tool results support arithmetic: result * 2, result + 10
          4. End with final_answer(answer: result)
          5. DO NOT use variable names in strings passed to tools:
             WRONG: calculate(expression: "x + 10")  # x is just text!
             RIGHT: x + 10                           # Direct arithmetic works!
          6. STOP after closing ``` - do not continue
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
