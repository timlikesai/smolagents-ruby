module Smolagents
  module Concerns
    # Generates system prompts for agents.
    #
    # Provides prompts that instruct the model to think in Ruby code,
    # including tool definitions, team descriptions, and custom instructions.
    #
    # @example Accessing the system prompt
    #   agent.system_prompt
    #   # => "You solve tasks by writing Ruby code..."
    #
    module PromptGeneration
      # Get the template path for this executor (if any).
      #
      # Subclasses can override to provide custom prompt templates.
      #
      # @return [String, nil] Path to template directory, or nil for defaults
      def template_path = nil

      # Generate the system prompt for the model.
      #
      # @return [String] Complete system prompt for the model
      def system_prompt
        base_prompt = Prompts::Agent.generate(
          tools: format_tools_for,
          team: managed_agent_descriptions,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool usage patterns.
      #
      # @return [String] Capabilities prompt addendum (may be empty)
      def capabilities_prompt
        Prompts.generate_capabilities(tools:, managed_agents: @managed_agents)
      end
    end
  end
end
