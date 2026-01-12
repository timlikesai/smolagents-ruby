module Smolagents
  module CLI
    module Commands
      def run_task(task)
        model = build_model(provider: options[:provider], model_id: options[:model],
                            api_key: options[:api_key], api_base: options[:api_base])
        tools = options[:tools].map { |n| Tools::REGISTRY.fetch(n) { raise Thor::Error, "Unknown tool: #{n}" }.new }
        agent_class = options[:agent_type] == "code" ? Agents::Code : Agents::ToolCalling
        agent = agent_class.new(tools:, model:, max_steps: options[:max_steps], logger: build_logger)

        say "Running agent...", :cyan
        result = agent.run(task, images: options[:image])

        if result.success?
          say "\nResult:", :green
          say result.output
          say "\n(#{result.steps.size} steps, #{result.timing.duration.round(2)}s)", :cyan
        else
          say "\nAgent did not complete successfully: #{result.state}", :red
          say "Last observation: #{result.steps.last&.observations&.slice(0, 200)}...", :yellow if result.steps.any?
        end
      end

      def tools
        say "Available tools:", :cyan
        Tools::REGISTRY.each do |name, tool_class|
          say "\n  #{name}", :green
          say "    #{tool_class.new.description}"
        end
      end

      def models
        say "Model providers:", :cyan
        {
          "OpenAI" => ["--provider openai --model gpt-4", "--provider openai --model gpt-3.5-turbo"],
          "Anthropic" => ["--provider anthropic --model claude-3-5-sonnet-20241022"],
          "Local (LM Studio)" => ["--provider openai --model local-model --api-base http://localhost:1234/v1"],
          "Local (Ollama)" => ["--provider openai --model llama3 --api-base http://localhost:11434/v1"]
        }.each do |name, examples|
          say "\n  #{name}:", :green
          examples.each { |ex| say "    #{ex}" }
        end
      end

      private

      def build_logger
        level = options[:verbose] ? AgentLogger::DEBUG : AgentLogger::WARN
        AgentLogger.new(output: $stderr, level:)
      end
    end
  end
end
