module Smolagents
  module Agents
    class Agent
      # Prompt generation methods for Agent.
      #
      # Generates system prompts and capabilities descriptions for the LLM.
      # Combines base prompts, tool descriptions, managed agent descriptions,
      # and custom instructions.
      #
      # @api private
      module Prompts
        # Returns the complete system prompt for the agent.
        #
        # Combines base code agent instructions, tool descriptions,
        # managed agent descriptions, custom instructions, and capabilities.
        #
        # @return [String] Complete system prompt sent to the model
        def system_prompt
          base_prompt = Smolagents::Prompts::CodeAgent.generate(
            tools: @tools.values.map { |t| t.format_for(:code) },
            team: managed_agent_descriptions,
            authorized_imports: @authorized_imports,
            custom: @custom_instructions
          )
          capabilities = capabilities_prompt
          capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
        end

        # Generates capabilities prompt showing tool usage patterns.
        #
        # Creates a supplementary prompt section describing available
        # capabilities based on registered tools and managed agents.
        #
        # @return [String] Capabilities prompt addendum (may be empty)
        def capabilities_prompt
          Smolagents::Prompts.generate_capabilities(
            tools: @tools,
            managed_agents: @managed_agents,
            agent_type: :code
          )
        end

        # Template path for custom prompts.
        #
        # Override in subclasses to provide custom prompt templates.
        #
        # @return [String, nil] Path to custom prompt template, or nil
        def template_path = nil
      end
    end
  end
end
