module Smolagents
  module Prompts
    ASSISTANT = "You are an expert assistant that solves tasks step by step.".freeze

    COMPLETION = "When you have the final answer, call: final_answer(answer: your_result)".freeze

    CODE_EXECUTION = <<~PROMPT.freeze
      Express your actions as Ruby code in ```ruby blocks.
      Use puts to display intermediate results you'll need in later steps.
      Your code will be executed and you'll see the output as an observation.
    PROMPT

    TOOLS_HEADER = "Available tools:".freeze
    TEAM_HEADER = "You can delegate tasks to these team members:".freeze

    GUIDANCE = <<~PROMPT.freeze
      Guidelines:
      - Work step by step, observing results before proceeding
      - Use tools only when needed
      - Don't repeat tool calls with identical arguments
    PROMPT

    def self.build(*fragments, tools: nil, team: nil, custom: nil)
      parts = fragments.dup

      if tools&.any?
        parts << TOOLS_HEADER
        parts << tools.map { |t| "  #{t}" }.join("\n")
      end

      if team&.any?
        parts << TEAM_HEADER
        parts << team.map { |t| "  #{t}" }.join("\n")
      end

      parts << custom if custom
      parts << COMPLETION

      parts.compact.reject(&:empty?).join("\n\n")
    end

    module Presets
      def self.code_agent(tools:, team: nil, custom: nil)
        Prompts.build(
          Prompts::ASSISTANT,
          Prompts::CODE_EXECUTION,
          Prompts::GUIDANCE,
          tools: tools,
          team: team,
          custom: custom
        )
      end

      def self.tool_calling(tools:, team: nil, custom: nil)
        Prompts.build(
          Prompts::ASSISTANT,
          Prompts::GUIDANCE,
          tools: tools,
          team: team,
          custom: custom
        )
      end
    end
  end
end
