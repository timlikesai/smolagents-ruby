module Smolagents
  module Concerns
    # Generates system prompts and capability descriptions for tool-calling agents.
    #
    # Provides the base prompts that instruct the model how to use tools,
    # including tool definitions, team descriptions, and custom instructions.
    #
    # @example Accessing the system prompt
    #   agent.system_prompt
    #   # => "You are a helpful AI assistant with the following tools:\n\n..."
    #
    # @example Customizing template path
    #   def template_path = "path/to/custom/templates"
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
      # Combines the base tool-calling prompt with capabilities summary.
      # Includes tool definitions, team descriptions, and custom instructions.
      #
      # @return [String] Complete system prompt for the model
      #
      # @example
      #   prompt = agent.system_prompt
      #   # => "You are a helpful AI assistant with the following tools:\n\n..."
      def system_prompt
        base_prompt = Prompts::Agent.generate(
          tools: format_tools_for(:tool_calling),
          team: managed_agent_descriptions,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool call patterns.
      #
      # Provides a summary of available tools and their usage patterns.
      # Used to augment the system prompt with additional context.
      #
      # @return [String] Capabilities prompt addendum (may be empty)
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools:,
          managed_agents: @managed_agents,
          agent_type: :tool
        )
      end
    end
  end
end
