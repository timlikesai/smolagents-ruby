module Smolagents
  module CLI
    module Commands
      # Information display commands (tools, models).
      #
      # Provides listing and help commands for displaying available tools
      # and model provider configurations.
      module Info
        # Model provider examples for CLI help output.
        PROVIDER_EXAMPLES = {
          "OpenAI" => [
            "--provider openai --model gpt-4",
            "--provider openai --model gpt-3.5-turbo"
          ],
          "Anthropic" => [
            "--provider anthropic --model claude-3-5-sonnet-20241022"
          ],
          "Local (LM Studio)" => [
            "--provider openai --model local-model --api-base http://localhost:1234/v1"
          ],
          "Local (Ollama)" => [
            "--provider openai --model llama3 --api-base http://localhost:11434/v1"
          ]
        }.freeze

        # Lists all available tools in the registry with descriptions.
        #
        # @return [void]
        def tools
          say "Available tools:", :cyan
          Tools::REGISTRY.each do |name, tool_class|
            say "\n  #{name}", :green
            say "    #{tool_class.new.description}"
          end
        end

        # Displays supported model providers and example configurations.
        #
        # @return [void]
        def models
          say "Model providers:", :cyan
          PROVIDER_EXAMPLES.each { |name, examples| print_provider_examples(name, examples) }
        end

        # Prints example configurations for a model provider.
        #
        # @param name [String] The provider name
        # @param examples [Array<String>] Example CLI arguments
        # @return [void]
        def print_provider_examples(name, examples)
          say "\n  #{name}:", :green
          examples.each { |ex| say "    #{ex}" }
        end
      end
    end
  end
end
