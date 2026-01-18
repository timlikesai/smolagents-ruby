module Smolagents
  module Builders
    # Build and agent construction methods for AgentBuilder.
    #
    # Handles the final build step and agent argument assembly.
    module AgentBuildConcern
      # Build the configured agent.
      #
      # Creates an Agent instance with all configured options. The model block
      # is evaluated at this point (lazy instantiation).
      #
      # @return [Agents::Agent] The configured agent
      # @raise [ArgumentError] If model is not configured
      #
      # @example Building an agent
      #   agent = Smolagents.agent
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .tools(:search)
      #     .max_steps(10)
      #     .build
      #   agent.class.name
      #   #=> "Smolagents::Agents::Agent"
      def build
        agent = Agents::Agent.new(**build_agent_args)
        configuration[:handlers].each { |event_type, block| agent.on(event_type, &block) }
        agent
      end

      # Return a copy of the current configuration.
      #
      # @return [Hash] Configuration hash
      def config = configuration.dup

      # Return a string representation of the builder.
      #
      # @return [String] Builder description
      def inspect
        tools_desc = (configuration[:tool_names] + configuration[:tool_instances].map do |t|
          t.name || t.class.name
        end).join(", ")
        "#<AgentBuilder tools=[#{tools_desc}] handlers=#{configuration[:handlers].size}>"
      end

      private

      # Build agent initialization arguments from configuration.
      # @return [Hash] Arguments for Agent.new
      def build_agent_args
        cfg = configuration
        {
          model: resolve_model,
          tools: resolve_tools,
          config: build_agent_config(cfg),
          managed_agents: cfg[:managed_agents].empty? ? nil : cfg[:managed_agents],
          logger: cfg[:logger],
          executor: cfg[:executor]
        }.compact
      end

      # Build an AgentConfig from builder configuration.
      # @param cfg [Hash] Full configuration
      # @return [Types::AgentConfig]
      def build_agent_config(cfg)
        Types::AgentConfig.create(**cfg.slice(*Types::AgentConfig.members))
      end
    end
  end
end
