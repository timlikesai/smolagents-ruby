module Smolagents
  module Utilities
    module Prompts
      # Shared formatting utilities for prompt generation.
      module Formatting
        class << self
          # Format team member entries for inclusion in prompts.
          def format_team_members(team)
            return nil unless team&.any?

            team.map { |m| "- #{m.split(":").first.strip}(task: \"what to do\")" }
          end

          # Build a section with header and items.
          def build_section(header, items)
            return nil unless items&.any?

            [header, *items].join("\n")
          end
        end
      end
    end
  end
end
