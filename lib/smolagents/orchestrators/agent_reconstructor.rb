module Smolagents
  module Orchestrators
    # Reconstructs agents inside Ractors from serialized configuration.
    #
    # This module runs in the child Ractor context, rebuilding agents
    # from primitive configuration since agents aren't Ractor-shareable.
    module AgentReconstructor
      module_function

      # Executes an agent task inside a Ractor.
      #
      # Reconstructs the agent from serialized configuration and runs it.
      # Requires SMOLAGENTS_API_KEY environment variable to be set.
      #
      # @param task_data [Hash] Task data with :task_id, :agent_name, :prompt, :trace_id
      # @param config [Hash] Agent reconstruction config from AgentSerializer
      # @return [Types::RunResult] The agent's run result
      # @raise [AgentConfigurationError] When API key is missing or reconstruction fails
      def execute_agent_task(task_data, config)
        api_key = ENV.fetch("SMOLAGENTS_API_KEY") do
          raise Smolagents::AgentConfigurationError, "SMOLAGENTS_API_KEY required for Ractor execution"
        end

        model = reconstruct_model(config, api_key)
        tools = reconstruct_tools(config[:tool_names])
        agent = reconstruct_agent(config, model, tools)

        agent.run(task_data[:prompt])
      end

      # Reconstructs a model inside a Ractor.
      #
      # Uses RactorModel with Net::HTTP since ruby-openai uses global
      # configuration which isn't Ractor-safe.
      #
      # @param config [Hash] Model configuration with :model_id, :model_config
      # @param api_key [String] The API key for authentication
      # @return [Models::RactorModel] The reconstructed model
      def reconstruct_model(config, api_key)
        model_opts = { model_id: config[:model_id], api_key: }
        model_opts.merge!(config[:model_config]) if config[:model_config]
        Smolagents::Models::RactorModel.new(**model_opts)
      end

      # Reconstructs tools from their registered names.
      #
      # @param tool_names [Array<String>] Names of tools to reconstruct
      # @return [Array<Tool>] The reconstructed tool instances
      # @raise [AgentConfigurationError] When a tool name is unknown
      def reconstruct_tools(tool_names)
        tool_names.map do |name|
          tool = Smolagents::Tools.get(name)
          unless tool
            raise Smolagents::AgentConfigurationError,
                  "Unknown tool: #{name}. Available: #{Smolagents::Tools.names.join(", ")}"
          end

          tool
        end
      end

      # Reconstructs an agent from configuration.
      #
      # @param config [Hash] Agent configuration with :agent_class, :max_steps, etc.
      # @param model [Model] The reconstructed model
      # @param tools [Array<Tool>] The reconstructed tools
      # @return [CodeAgent, ToolCallingAgent] The reconstructed agent
      # @raise [AgentConfigurationError] When agent class is unknown
      def reconstruct_agent(config, model, tools)
        agent_class = Object.const_get(config[:agent_class])
        agent_class.new(**build_agent_opts(config, model, tools))
      rescue NameError => e
        raise Smolagents::AgentConfigurationError, "Unknown agent class: #{config[:agent_class]} - #{e.message}"
      end

      # Builds agent constructor options from config.
      #
      # @param config [Hash] Agent configuration
      # @param model [Model] The model instance
      # @param tools [Array<Tool>] The tool instances
      # @return [Hash] Constructor options for the agent
      def build_agent_opts(config, model, tools)
        { model:, tools:, max_steps: config[:max_steps] }.tap do |opts|
          opts[:planning_interval] = config[:planning_interval] if config[:planning_interval]
          opts[:custom_instructions] = config[:custom_instructions] if config[:custom_instructions]
        end
      end
    end
  end
end
