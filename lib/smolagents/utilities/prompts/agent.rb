require_relative "agent/tool_formatting"
require_relative "agent/sections"

module Smolagents
  module Utilities
    module Prompts
      # Agent prompt generator - all agents think in Ruby code.
      #
      # Generates system prompts that instruct models to write Ruby code blocks
      # using tools as method calls with keyword arguments.
      #
      # Supports budget-aware trimming via max_tokens: lower-priority sections
      # are dropped gracefully when context is tight.
      #
      # @example Generate a prompt
      #   Agent.generate(tools: [search, calculator])
      # @example Budget-constrained prompt
      #   Agent.generate(tools: tools, max_tokens: 500)
      module Agent
        CHARS_PER_TOKEN = 4

        class << self
          include ToolFormatting

          def generate(tools:, team: nil, authorized_imports: nil, custom: nil, max_tokens: nil,
                       tool_calling_mode: :code, **)
            sections = prioritized_sections(tools, team, authorized_imports, custom, tool_calling_mode)
            max_tokens ? assemble_within_budget(sections, max_tokens) : assemble(sections)
          end

          private

          def prioritized_sections(tools, team, authorized_imports, custom, mode)
            { p1: essential_sections(tools, team, authorized_imports, custom, mode),
              p2: p2_sections(mode), p3: mode == :native ? [] : [Sections::HELPERS] }
          end

          def p2_sections(mode)
            if mode == :native
              [Templates::TOOL_OUTPUT_SECURITY]
            else
              [Sections::EXAMPLE, Templates::TOOL_OUTPUT_SECURITY]
            end
          end

          def essential_sections(tools, team, authorized_imports, custom, mode)
            intro = mode == :native ? Sections::NATIVE_INTRO : Sections::INTRO
            caps = mode == :native ? nil : Sections::CAPABILITIES
            [intro, caps, tools_section(tools),
             team_section(team), imports_section(authorized_imports), custom]
          end

          def assemble(sections) = sections.values.flatten.compact.join("\n\n")

          def assemble_within_budget(sections, max_tokens)
            max_chars = max_tokens * CHARS_PER_TOKEN
            result = sections[:p1].compact.join("\n\n")
            result = append_if_fits(result, sections[:p2], max_chars)
            append_if_fits(result, sections[:p3], max_chars)
          end

          def append_if_fits(result, sections, max_chars)
            sections.compact.each do |section|
              candidate = "#{result}\n\n#{section}"
              return result if candidate.length > max_chars

              result = candidate
            end
            result
          end

          def tools_section(tools)
            return nil unless tools&.any?

            parts = ["TOOLS AVAILABLE:", *tools.map { |t| format_tool(t) }]
            hints = tools.filter_map { |t| tool_hint(t) }
            parts << hints.join("\n") if hints.any?
            parts.join("\n\n")
          end

          def tool_hint(tool)
            return nil unless tool.respond_to?(:name)

            TOOL_HINTS[tool.name.to_s]
          end

          TOOL_HINTS = {
            "duckduckgo_search" => "# search results are strings",
            "google_search" => "# search results are strings",
            "visit_webpage" => "# visit_webpage returns markdown text",
            "ruby" => "# ruby returns stdout + final expression value",
            "ask_user" => "# ask_user returns the user's typed response",
            "transcribe" => "# transcribe returns transcribed text",
            "spawn_agent" => "# spawn_agent returns the sub-agent's result"
          }.freeze

          def team_section(team)
            Formatting.build_section("TEAM MEMBERS (call like tools):", Formatting.format_team_members(team))
          end

          def imports_section(imports) = imports&.any? ? "ALLOWED REQUIRES: #{imports.join(", ")}" : nil
        end
      end
    end
  end
end
