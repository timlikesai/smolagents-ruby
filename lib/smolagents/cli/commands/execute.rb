module Smolagents
  module CLI
    module Commands
      # Agent execution command implementation.
      #
      # Handles building and running agents with configured models and tools.
      # Includes tool instantiation from registry and logger configuration.
      module Execute
        # Executes an agent task with specified tools and model configuration.
        #
        # Builds a model instance based on provided provider and credentials,
        # instantiates tools from the registry, creates an agent, and runs the task.
        #
        # @param task [String] The task description for the agent to execute
        # @return [void]
        def run_task(task)
          agent = build_agent
          say "Running agent...", :cyan
          result = agent.run(task, images: options[:image])
          display_result(result)
        end

        private

        def build_agent
          model = build_model(
            provider: options[:provider], model_id: options[:model],
            api_key: options[:api_key], api_base: options[:api_base]
          )
          Agents::Agent.new(tools: build_tools, model:, max_steps: options[:max_steps], logger: build_logger)
        end

        def build_tools
          options[:tools].map do |name|
            Tools::REGISTRY.fetch(name) { raise Thor::Error, "Unknown tool: #{name}" }.new
          end
        end

        def build_logger
          level = options[:verbose] ? AgentLogger::DEBUG : AgentLogger::WARN
          AgentLogger.new(output: $stderr, level:)
        end
      end
    end
  end
end
