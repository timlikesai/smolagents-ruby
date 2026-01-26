module Smolagents
  module Utilities
    module Prompts
      # Shared formatting utilities for prompt generation.
      module Formatting
        class << self
          # Format a tool documentation line
          def format_tool_line(tool_doc)
            "- #{tool_doc}"
          end

          # Format team member entries for inclusion in prompts
          def format_team_members(team)
            return nil unless team&.any?

            team.map { |m| "- #{m.split(":").first.strip}(task: \"what to do\")" }
          end

          # Format Ruby keyword arguments for display
          def format_ruby_args(args)
            args.map do |key, value|
              formatted = value.is_a?(String) ? "\"#{value}\"" : value.inspect
              "#{key}: #{formatted}"
            end.join(", ")
          end

          # Build a section with header and items
          def build_section(header, items)
            return nil unless items&.any?

            [header, *items].join("\n")
          end

          # Generate example args from tool inputs spec
          def generate_example_args(inputs)
            inputs.transform_values do |spec|
              Templates.example_for_type(spec[:type], spec[:description])
            end
          end
        end
      end
    end
  end
end
