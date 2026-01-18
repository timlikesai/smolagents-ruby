module Smolagents
  module Utilities
    module Prompts
      # Generates capabilities prompts from agent configuration.
      #
      # @example Generate capabilities for tools
      #   prompt = CapabilitiesGenerator.generate(tools: { "search" => tool }, agent_type: :code)
      module CapabilitiesGenerator
        class << self
          def generate(tools:, managed_agents: nil, agent_type: :tool)
            parts = []
            parts << tool_capabilities(tools, agent_type) if tools&.any?
            parts << agent_capabilities(managed_agents) if managed_agents&.any?
            parts.compact.join("\n\n")
          end

          private

          def tool_capabilities(tools, agent_type)
            user_tools = tools.except("final_answer")
            return nil if user_tools.empty?

            examples = user_tools.values.take(3).map { |tool| tool_example(tool, agent_type) }
            return nil if examples.empty?

            "TOOL USAGE:\n#{examples.join("\n\n")}"
          end

          def tool_example(tool, agent_type)
            args = Formatting.generate_example_args(tool.inputs)
            call = "#{tool.name}(#{Formatting.format_ruby_args(args)})"

            if agent_type == :code
              "# #{tool.description}\nresult = #{call}"
            else
              "# #{tool.description}\n#{call}"
            end
          end

          def agent_capabilities(managed_agents)
            return nil if managed_agents.nil? || managed_agents.empty?

            examples = managed_agents.values.take(2).map { |agent| agent_example(agent) }
            return nil if examples.empty?

            "SUB-AGENTS:\n#{examples.join("\n\n")}"
          end

          def agent_example(agent)
            "# #{agent.description}\n#{agent.name}(task: \"describe what you need\")"
          end
        end
      end
    end
  end
end
