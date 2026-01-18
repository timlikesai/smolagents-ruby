module Smolagents
  module Concerns
    # Support for multi-agent teams where agents can delegate to other agents
    #
    # Wraps agent instances in ManagedAgentTool so they can be used as tools.
    # Maintains a hash of agents by name and provides descriptions for prompts.
    #
    # @example Using managed agents
    #   searcher = CodeAgent.new(model: gpt4, tools: [web_search])
    #   writer = CodeAgent.new(model: gpt4, tools: [file_write])
    #
    #   coordinator = CodeAgent.new(
    #     model: gpt4,
    #     managed_agents: [searcher, writer]
    #   )
    #
    # @see ManagedAgentTool For tool wrapping logic
    module ManagedAgents
      # Hook called when module is included
      # @api private
      def self.included(base)
        base.attr_reader :managed_agents
      end

      private

      # Initialize managed agents from array.
      #
      # Converts agent instances to ManagedAgentTools and indexes by name.
      # Skips agents that are already wrapped.
      #
      # @param managed_agents [Array<Agent>, nil] Agents to wrap
      # @return [void]
      def setup_managed_agents(managed_agents)
        @managed_agents = (managed_agents || []).to_h do |agent|
          tool = agent.is_a?(ManagedAgentTool) ? agent : ManagedAgentTool.new(agent:)
          [tool.name, tool]
        end
      end

      # Combine regular tools with managed agent tools.
      #
      # Merges managed agents (as tools) with regular tools.
      # Ensures final_answer tool is always present.
      #
      # @param tools [Array<Tool>] Regular tools
      # @return [Hash<String, Tool>] Combined tool hash keyed by name
      def tools_with_managed_agents(tools)
        tool_hash = tools.to_h { |tool| [tool.name, tool] }

        # Always ensure final_answer is available
        tool_hash["final_answer"] ||= FinalAnswerTool.new

        tool_hash.merge(@managed_agents || {})
      end

      # Get descriptions of managed agents for prompts.
      #
      # Formats managed agents as "name: description" strings
      # suitable for inclusion in system prompts.
      #
      # @return [Array<String>, nil] Agent descriptions or nil if no agents
      def managed_agent_descriptions
        return nil unless @managed_agents&.any?

        @managed_agents.values.map { |agent| "#{agent.name}: #{agent.description}" }
      end
    end
  end
end
