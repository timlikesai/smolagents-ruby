require_relative "prompts/templates"
require_relative "prompts/formatting"
require_relative "prompts/agent"
require_relative "prompts/code_agent"
require_relative "prompts/capabilities_generator"

module Smolagents
  module Utilities
    # Dynamic prompt generation for agent system prompts.
    #
    # All agents think and act in Ruby code. Tool calls use the pattern:
    #   result = tool_name(arg: value)
    #
    # @example Generate an agent prompt
    #   prompt = Prompts.generate(tools: [search, calculator])
    module Prompts
      def self.generate(...) = CodeAgent.generate(...)

      # Generates capabilities prompt showing tool usage.
      #
      # @param tools [Hash<String, Tool>] Available tools keyed by name
      # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents
      # @return [String] Prompt addendum with usage examples
      def self.generate_capabilities(tools:, managed_agents: nil, **)
        CapabilitiesGenerator.generate(tools:, managed_agents:)
      end
    end
  end
end
