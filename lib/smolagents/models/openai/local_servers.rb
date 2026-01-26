module Smolagents
  module Models
    module OpenAI
      # Factory methods for local inference servers.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for popular local inference servers.
      #
      # Supported servers:
      # - **LM Studio**: GUI app with OpenAI-compatible server (port 1234)
      # - **Ollama**: CLI tool with OpenAI-compatible endpoint (port 11434)
      # - **llama.cpp**: Lightweight server for GGUF models (port 8080)
      # - **MLX-LM**: Apple Silicon optimized server (port 8080)
      # - **vLLM**: High-throughput production server (port 8000)
      # - **Text Generation WebUI**: Feature-rich web interface (port 5000)
      #
      # @example LM Studio (most common for development)
      #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
      #
      # @example Ollama with custom port
      #   model = OpenAIModel.ollama("llama3:latest", port: 11435)
      #
      # @example Remote server (not localhost)
      #   model = OpenAIModel.lm_studio("gemma-3n", host: "192.168.1.100")
      #
      # @see CloudProviders For cloud API factory methods
      module LocalServers
        # @return [Integer] Default max tokens to prevent runaway generation.
        DEFAULT_MAX_TOKENS = 8192

        # @return [Hash{Symbol => Integer}] Default ports for local servers.
        PORTS = {
          lm_studio: 1234,
          ollama: 11_434,
          llama_cpp: 8080,
          mlx_lm: 8080,
          vllm: 8000,
          text_generation_webui: 5000
        }.freeze

        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for local server factory methods.
        # Generated dynamically from PORTS configuration.
        module ClassMethods
          LocalServers::PORTS.each do |server, default_port|
            # Defines a factory method for each local server type.
            #
            # @param model_id [String] Model identifier
            # @param host [String] Server hostname (default: "localhost")
            # @param port [Integer] Server port (default: server-specific)
            # @param max_tokens [Integer] Max response tokens (default: 8192)
            # @param options [Hash] Additional options passed to OpenAIModel
            # @return [OpenAIModel] Configured model instance
            define_method(server) do |model_id, host: "localhost", port: default_port,
                                      max_tokens: DEFAULT_MAX_TOKENS, **options|
              new(
                model_id:,
                api_base: "http://#{host}:#{port}/v1",
                api_key: "not-needed",
                max_tokens:,
                **options
              )
            end
          end
        end
      end
    end
  end
end
