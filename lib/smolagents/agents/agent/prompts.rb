module Smolagents
  module Agents
    class Agent
      # Prompt generation for Agent.
      #
      # Generates system prompts that instruct the model to think in Ruby code.
      #
      # @api private
      module Prompts
        # Returns the complete system prompt for the agent.
        #
        # @return [String] Complete system prompt sent to the model
        def system_prompt
          base_prompt = Smolagents::Prompts.generate(
            tools: @tools.values.map { |t| t.format_for(:default) },
            team: managed_agent_descriptions,
            authorized_imports: @authorized_imports,
            custom: @custom_instructions
          )
          capabilities = capabilities_prompt
          capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
        end

        # Generates capabilities prompt showing tool usage patterns.
        #
        # @return [String] Capabilities prompt addendum (may be empty)
        def capabilities_prompt
          Smolagents::Prompts.generate_capabilities(tools: @tools, managed_agents: @managed_agents)
        end

        # Template path for custom prompts.
        #
        # @return [String, nil] Path to custom prompt template, or nil
        def template_path = nil
      end
    end
  end
end
