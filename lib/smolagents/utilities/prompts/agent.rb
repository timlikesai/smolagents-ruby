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
      # @example Generate an agent prompt
      #   prompt = Agent.generate(tools: [search, calculator])
      module Agent
        class << self
          include ToolFormatting

          def generate(tools:, team: nil, authorized_imports: nil, custom: nil, tool_disclosure: :full)
            build_prompt(tools:, team:, authorized_imports:, custom:, tool_disclosure:)
          end

          private

          def build_prompt(tools:, team:, authorized_imports:, custom:, tool_disclosure:)
            prompt_sections(tools, team, authorized_imports, custom, tool_disclosure).compact.join("\n\n")
          end

          def prompt_sections(tools, team, authorized_imports, custom, tool_disclosure)
            helpers = tool_disclosure == :progressive ? PROGRESSIVE_HELPERS : Sections::HELPERS
            [Sections::INTRO, tools_section(tools, tool_disclosure), Sections::EXAMPLES, team_section(team),
             imports_section(authorized_imports), Templates::TOOL_OUTPUT_SECURITY,
             Sections::RULES, helpers, tool_usage_section(tools), custom]
          end

          PROGRESSIVE_HELPERS = <<~PROMPT.freeze
            TOOL HELP:
            - `help(:tool_name)` - Get full usage details, parameters, and examples for any tool
            - `help` - List all available tools

            DEBUG HELPERS (if stuck):
            - `puts inspect_state` - see all stored @variables with their values
            - `puts vars` - list variable names
          PROMPT

          def tools_section(tools, tool_disclosure = :full)
            return nil unless tools&.any?

            formatter = tool_disclosure == :progressive ? :format_tool_summary : :format_tool
            header = tool_disclosure == :progressive ? tools_header_progressive : "TOOLS AVAILABLE:"
            [header, *tools.map { |t| send(formatter, t) }].join("\n\n")
          end

          def tools_header_progressive = "TOOLS AVAILABLE (use `help(:tool_name)` for full details):"

          def team_section(team)
            Formatting.build_section("TEAM MEMBERS (call like tools):", Formatting.format_team_members(team))
          end

          def imports_section(imports) = imports&.any? ? "ALLOWED REQUIRES: #{imports.join(", ")}" : nil

          def tool_usage_section(tools)
            return nil unless tools&.any?

            hints = tools.take(3).filter_map { |tool| tool_usage_hint(tool) }
            hints.empty? ? Sections::TOOL_USAGE : "#{Sections::TOOL_USAGE}\n#{hints.join("\n")}"
          end

          def tool_usage_hint(tool)
            return nil unless tool.respond_to?(:name) && tool.respond_to?(:description)

            generate_hint_for_tool(tool.name.to_s, tool.description.to_s.downcase)
          end

          def generate_hint_for_tool(name, desc)
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
