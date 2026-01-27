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

          def generate(tools:, team: nil, authorized_imports: nil, custom: nil)
            build_prompt(tools:, team:, authorized_imports:, custom:)
          end

          private

          def build_prompt(tools:, team:, authorized_imports:, custom:)
            prompt_sections(tools, team, authorized_imports, custom).compact.join("\n\n")
          end

          def prompt_sections(tools, team, authorized_imports, custom)
            [Sections::INTRO, tools_section(tools), Sections::EXAMPLES, team_section(team),
             imports_section(authorized_imports), Templates::TOOL_OUTPUT_SECURITY,
             Sections::RULES, tool_usage_section(tools), custom]
          end

          def tools_section(tools)
            return nil unless tools&.any?

            ["TOOLS AVAILABLE:", *tools.map { |t| format_tool(t) }].join("\n\n")
          end

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
