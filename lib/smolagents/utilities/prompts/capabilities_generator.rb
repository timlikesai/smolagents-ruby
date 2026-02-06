module Smolagents
  module Utilities
    module Prompts
      # Generates capabilities prompt for sub-agents only.
      #
      # Tool usage examples are already provided by ToolFormatting in the main
      # prompt. This generator adds sub-agent usage examples when present.
      #
      # @example Generate capabilities for managed agents
      #   prompt = CapabilitiesGenerator.generate(tools: {}, managed_agents: agents)
      module CapabilitiesGenerator
        class << self
          def generate(managed_agents: nil, **) = agent_capabilities(managed_agents)

          private

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
