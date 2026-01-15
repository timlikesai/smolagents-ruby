module Smolagents
  module Orchestrators
    # Serializes agent configuration for Ractor transfer.
    #
    # Agents cannot be shared directly across Ractors, so we extract
    # all necessary configuration into shareable primitive types that
    # can be used to reconstruct the agent in a child Ractor.
    module AgentSerializer
      module_function

      # Builds a frozen hash of task data for Ractor transfer.
      #
      # @param task [Types::RactorTask] the task to serialize
      # @return [Hash] frozen hash with task_id, agent_name, prompt, trace_id
      def build_task_hash(task)
        {
          task_id: task.task_id,
          agent_name: task.agent_name,
          prompt: task.prompt,
          trace_id: task.trace_id
        }.freeze
      end

      # Prepares agent configuration for Ractor transfer.
      #
      # Extracts all configuration needed to reconstruct the agent in a child
      # Ractor, including model settings, tool names, and agent parameters.
      #
      # @param agent [CodeAgent, ToolCallingAgent] the agent to serialize
      # @param task [Types::RactorTask] the task being executed
      # @return [Hash] frozen configuration hash
      def prepare_agent_config(agent, task)
        {
          **extract_model_attrs(agent),
          **extract_agent_attrs(agent, task)
        }.freeze
      end

      # Extracts model-related attributes from an agent.
      #
      # @param agent [CodeAgent, ToolCallingAgent] the agent
      # @return [Hash] model class, ID, and configuration
      def extract_model_attrs(agent)
        {
          model_class: agent.model.class.name,
          model_id: agent.model.model_id,
          model_config: extract_model_config(agent.model)
        }
      end

      # Extracts agent-related attributes for reconstruction.
      #
      # @param agent [CodeAgent, ToolCallingAgent] the agent
      # @param task [Types::RactorTask] the task with override config
      # @return [Hash] agent class, max_steps, tool_names, planning_interval
      def extract_agent_attrs(agent, task)
        {
          agent_class: agent.class.name,
          max_steps: task.config[:max_steps] || agent.max_steps,
          tool_names: agent.tools.keys.freeze,
          planning_interval: agent.planning_interval,
          custom_instructions: agent.instance_variable_get(:@custom_instructions)
        }
      end

      # Extracts model configuration for reconstruction.
      #
      # @param model [Model] the model instance
      # @return [Hash] frozen configuration with api_base, temperature, max_tokens
      def extract_model_config(model)
        {
          api_base: extract_api_base(model),
          temperature: extract_ivar(model, :@temperature),
          max_tokens: extract_ivar(model, :@max_tokens)
        }.compact.freeze
      end

      # Extracts the API base URL from a model if available.
      #
      # @param model [Model] the model instance
      # @return [String, nil] the API base URL or nil
      def extract_api_base(model)
        return nil unless model.respond_to?(:generate)

        model.instance_variable_get(:@client)&.uri_base
      end

      # Safely extracts an instance variable from an object.
      #
      # @param obj [Object] the object to extract from
      # @param name [Symbol] the instance variable name
      # @return [Object, nil] the value or nil if not defined
      def extract_ivar(obj, name)
        obj.instance_variable_defined?(name) ? obj.instance_variable_get(name) : nil
      end
    end
  end
end
