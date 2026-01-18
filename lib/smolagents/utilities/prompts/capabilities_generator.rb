module Smolagents
  module Utilities
    module Prompts
      # Generates capabilities prompts showing available tools.
      #
      # All agents think in code. Tool calls are always `result = tool(args)`.
      #
      # @example Generate capabilities for tools
      #   prompt = CapabilitiesGenerator.generate(tools: { "search" => tool })
      module CapabilitiesGenerator
        class << self
          def generate(tools:, managed_agents: nil, **)
            parts = []
            parts << tool_capabilities(tools) if tools&.any?
            parts << agent_capabilities(managed_agents) if managed_agents&.any?
            parts.compact.join("\n\n")
          end

          private

          def tool_capabilities(tools)
            user_tools = tools.except("final_answer")
            return nil if user_tools.empty?

            examples = user_tools.values.take(3).map { |tool| tool_example(tool) }
            return nil if examples.empty?

            "TOOL USAGE:\n#{examples.join("\n\n")}"
          end

          def tool_example(tool)
            args = Formatting.generate_example_args(tool.inputs)
            call = "#{tool.name}(#{Formatting.format_ruby_args(args)})"

            # Always use result = tool() pattern for lazy evaluation
            "# #{tool.description}\nresult = #{call}"
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
