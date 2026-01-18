require_relative "prompts/templates"
require_relative "prompts/formatting"
require_relative "prompts/agent"
require_relative "prompts/code_agent"
require_relative "prompts/capabilities_generator"

module Smolagents
  module Utilities
    # Dynamic prompt generation for agent system prompts.
    #
    # All agents use Ruby method call syntax for tools - it's natural for LLMs
    # and our flexible input handling accepts variations gracefully.
    #
    # @example Generate an agent prompt
    #   prompt = Prompts.agent(tools: [search, calculator])
    #
    # @example Generate a code agent prompt
    #   prompt = Prompts.code(tools: [interpreter], custom: "Show your work")
    module Prompts
      # Convenience methods
      def self.agent(...) = Agent.generate(...)
      def self.code(...) = CodeAgent.generate(...)

      # Generates capabilities prompt from agent configuration.
      #
      # @param tools [Hash<String, Tool>] Available tools keyed by name
      # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents
      # @param agent_type [Symbol] :code or :tool (both use Ruby syntax)
      # @return [String] Prompt addendum with usage examples
      def self.generate_capabilities(tools:, managed_agents: nil, agent_type: :tool)
        CapabilitiesGenerator.generate(tools:, managed_agents:, agent_type:)
      end
    end
  end
end
