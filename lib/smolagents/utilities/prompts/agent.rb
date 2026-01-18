module Smolagents
  module Utilities
    module Prompts
      # Base agent prompt - Ruby method calls for tools.
      #
      # @example Generate a base agent prompt
      #   prompt = Agent.generate(tools: [search, calculator])
      module Agent
        INTRO = <<~PROMPT.freeze
          You solve tasks by calling tools. Tools are Ruby methods.

          Call one tool at a time:
          tool_name(arg: "value")

          After the tool runs, you'll see the result. Then call another tool or finish.
          To finish, call final_answer with your result:
          final_answer(answer: "your answer here")
        PROMPT

        DEFAULT_EXAMPLE = <<~PROMPT.freeze
          Example:
          Task: "What is the capital of France?"
          search(query: "capital of France")
          Observation:
          <tool_output>
          Paris is the capital and largest city of France...
          </tool_output>
          final_answer(answer: "Paris")
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Call one tool at a time
          2. Use argument names from tool descriptions
          3. Finish with final_answer(answer: "result")
        PROMPT

        class << self
          def generate(tools:, team: nil, custom: nil)
            [
              INTRO,
              tools_section(tools),
              DEFAULT_EXAMPLE,
              team_section(team),
              Templates::TOOL_OUTPUT_SECURITY,
              RULES,
              custom
            ].compact.join("\n\n")
          end

          private

          def tools_section(tools)
            return nil unless tools&.any?

            formatted = tools.map { |t| Formatting.format_tool_line(t) }
            Formatting.build_section("TOOLS:", formatted)
          end

          def team_section(team)
            members = Formatting.format_team_members(team)
            Formatting.build_section("TEAM (call like tools):", members)
          end
        end
      end
    end
  end
end
