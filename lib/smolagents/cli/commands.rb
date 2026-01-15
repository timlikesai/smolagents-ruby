module Smolagents
  module CLI
    # Command implementations for the CLI interface.
    #
    # This module provides core command methods for running tasks, listing tools, and displaying
    # model information. It's intended to be included in a Thor command class.
    #
    # @example Running a task
    #   class MyCLI < Thor
    #     include Smolagents::CLI::Commands
    #     include Smolagents::CLI::ModelBuilder
    #   end
    #
    #   MyCLI.start(["execute", "What is the capital of France?"])
    #
    # @see Main
    # @see ModelBuilder
    module Commands
      # Executes an agent task with specified tools and model configuration.
      #
      # Builds a model instance based on provided provider and credentials, instantiates tools
      # from the registry, creates an appropriate agent (code or tool-calling), and runs the
      # task. Displays the result with execution timing and step count.
      #
      # @param task [String] The task description for the agent to execute
      # @return [void]
      #
      # @example Run a web search task
      #   run_task("Find the latest Ruby release notes")
      #
      # @example With custom options
      #   options = {
      #     provider: "anthropic",
      #     model: "claude-3-5-sonnet-20241022",
      #     tools: ["duckduckgo_search"],
      #     agent_type: "tool_calling",
      #     max_steps: 5,
      #     verbose: true
      #   }
      #
      # @note This method is called by the `execute` Thor command
      # @note Requires options to be set via Thor option declarations
      # @see #build_model
      # @see #build_logger
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
        agent_class = options[:agent_type] == "code" ? Agents::Code : Agents::ToolCalling
        agent_class.new(tools: build_tools, model:, max_steps: options[:max_steps], logger: build_logger)
      end

      def build_tools
        options[:tools].map do |name|
          Tools::REGISTRY.fetch(name) { raise Thor::Error, "Unknown tool: #{name}" }.new
        end
      end

      def display_result(result)
        if result.success?
          display_success(result)
        else
          display_failure(result)
        end
      end

      def display_success(result)
        say "\nResult:", :green
        say result.output
        say "\n(#{result.steps.size} steps, #{result.timing.duration.round(2)}s)", :cyan
      end

      def display_failure(result)
        say "\nAgent did not complete successfully: #{result.state}", :red
        return unless result.steps.any?

        say "Last observation: #{result.steps.last&.observations&.slice(0, 200)}...", :yellow
      end

      public

      # Lists all available tools in the registry with descriptions.
      #
      # Displays a formatted list of tools that can be used with agents, including
      # a brief description of what each tool does.
      #
      # @return [void]
      #
      # @example List tools
      #   tools
      #
      # @note Called by the `tools` Thor command
      # @see Tools::REGISTRY
      def tools
        say "Available tools:", :cyan
        Tools::REGISTRY.each do |name, tool_class|
          say "\n  #{name}", :green
          say "    #{tool_class.new.description}"
        end
      end

      # Displays supported model providers and example configurations.
      #
      # Shows available model providers (OpenAI, Anthropic, local options) with example
      # command-line arguments for each provider and model variant.
      #
      # @return [void]
      #
      # @example Show available models
      #   models
      #
      # @note Called by the `models` Thor command
      # @see #print_provider_examples
      def models
        say "Model providers:", :cyan
        {
          "OpenAI" => ["--provider openai --model gpt-4", "--provider openai --model gpt-3.5-turbo"],
          "Anthropic" => ["--provider anthropic --model claude-3-5-sonnet-20241022"],
          "Local (LM Studio)" => ["--provider openai --model local-model --api-base http://localhost:1234/v1"],
          "Local (Ollama)" => ["--provider openai --model llama3 --api-base http://localhost:11434/v1"]
        }.each { |name, examples| print_provider_examples(name, examples) }
      end

      # Prints example configurations for a model provider.
      #
      # Helper method to display formatted provider name and example command-line
      # arguments for different models within that provider.
      #
      # @param name [String] The name of the model provider (e.g., "OpenAI", "Anthropic")
      # @param examples [Array<String>] Array of example CLI argument strings for that provider
      # @return [void]
      #
      # @example Print OpenAI examples
      #   print_provider_examples("OpenAI", [
      #     "--provider openai --model gpt-4",
      #     "--provider openai --model gpt-3.5-turbo"
      #   ])
      #
      # @note This is a private helper method used by {#models}
      # @see #models
      def print_provider_examples(name, examples)
        say "\n  #{name}:", :green
        examples.each { |ex| say "    #{ex}" }
      end

      private

      # Builds a logger instance with appropriate logging level.
      #
      # Creates an AgentLogger configured based on the verbose option. In verbose mode,
      # logs debug-level messages; otherwise logs only warnings and errors.
      #
      # @return [AgentLogger] Logger instance configured for the current verbosity level
      #
      # @example Build logger in verbose mode
      #   options[:verbose] = true
      #   logger = build_logger
      #   logger.level #=> AgentLogger::DEBUG
      #
      # @example Build logger in quiet mode
      #   options[:verbose] = false
      #   logger = build_logger
      #   logger.level #=> AgentLogger::WARN
      #
      # @note Logs are written to standard error ($stderr)
      # @see AgentLogger
      # @see #run_task
      def build_logger
        level = options[:verbose] ? AgentLogger::DEBUG : AgentLogger::WARN
        AgentLogger.new(output: $stderr, level:)
      end
    end
  end
end
