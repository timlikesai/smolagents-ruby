module Smolagents
  module Models
    module OpenAI
      # Factory methods for local inference servers.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for popular local inference servers. Each factory method
      # sets appropriate defaults for the server type (port, API key, max_tokens).
      #
      # Supported servers:
      # - **LM Studio**: GUI app with OpenAI-compatible server (port 1234)
      # - **Ollama**: CLI tool with OpenAI-compatible endpoint (port 11434)
      # - **llama.cpp**: Lightweight server for GGUF models (port 8080)
      # - **MLX-LM**: Apple Silicon optimized server (port 8080)
      # - **vLLM**: High-throughput production server (port 8000)
      # - **Text Generation WebUI**: Feature-rich web interface (port 5000)
      #
      # All local servers use "not-needed" as the API key since they typically
      # don't require authentication.
      #
      # @example LM Studio (most common for development)
      #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
      #   response = model.generate([ChatMessage.user("Hello!")])
      #
      # @example Ollama with custom port
      #   model = OpenAIModel.ollama("llama3:latest", port: 11435)
      #
      # @example llama.cpp server
      #   model = OpenAIModel.llama_cpp("mistral-7b-instruct-v0.2.Q4_K_M.gguf")
      #
      # @example Remote server (not localhost)
      #   model = OpenAIModel.lm_studio("gemma-3n", host: "192.168.1.100")
      #
      # @see OpenAIModel#initialize For direct instantiation
      # @see CloudProviders For cloud API factory methods
      module LocalServers
        # @return [Integer] Default max tokens for local models to prevent runaway generation.
        #   Some models (especially "thinking" variants) can get stuck in loops.
        #   Users can override with max_tokens: param. Set to 8192 for a reasonable balance.
        DEFAULT_MAX_TOKENS = 8192

        # @return [Hash{Symbol => Integer}] Default ports for popular local inference servers.
        #   Each server type has a conventional default port that users typically use.
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
        #
        # These methods are extended onto OpenAIModel when LocalServers is included,
        # providing convenient factory methods for creating models connected to
        # local inference servers.
        module ClassMethods
          # Creates a model connected to an LM Studio server.
          #
          # LM Studio is a desktop application that provides an OpenAI-compatible
          # API for running local models. It's popular for development and testing.
          #
          # @param model_id [String] Model identifier as shown in LM Studio's UI
          #   (e.g., "gemma-3n-e4b-it-q8_0", "llama-3-8b-instruct")
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 1234 (LM Studio's default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          #   Set to prevent runaway generation with some models.
          # @param options [Hash] Additional options passed to OpenAIModel
          # @option options [Float] :temperature Sampling temperature (0.0-2.0)
          # @option options [Integer] :timeout Request timeout in seconds
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
          #   response = model.generate([ChatMessage.user("Hello!")])
          #
          # @example Custom configuration
          #   model = OpenAIModel.lm_studio("llama-3-8b",
          #     host: "192.168.1.100",
          #     port: 1234,
          #     temperature: 0.5,
          #     max_tokens: 4096
          #   )
          #
          # @see https://lmstudio.ai LM Studio documentation
          def lm_studio(model_id, host: "localhost", port: PORTS[:lm_studio],
                        max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates a model connected to an Ollama server.
          #
          # Ollama is a CLI tool for running local LLMs with an OpenAI-compatible
          # API endpoint. Models are specified using Ollama's naming convention
          # (e.g., "llama3:latest", "codellama:7b").
          #
          # @param model_id [String] Model identifier in Ollama format
          #   (e.g., "llama3:latest", "codellama:7b", "mistral:instruct")
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 11434 (Ollama's default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.ollama("llama3:latest")
          #
          # @example With specific model version
          #   model = OpenAIModel.ollama("codellama:7b-instruct")
          #
          # @see https://ollama.ai Ollama documentation
          def ollama(model_id, host: "localhost", port: PORTS[:ollama],
                     max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates a model connected to a llama.cpp server.
          #
          # llama.cpp is a lightweight C++ inference engine that can run GGUF models.
          # The server provides an OpenAI-compatible API endpoint.
          #
          # @param model_id [String] Model identifier (often the GGUF filename)
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 8080 (llama.cpp's default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.llama_cpp("mistral-7b-instruct")
          #
          # @see https://github.com/ggerganov/llama.cpp llama.cpp repository
          def llama_cpp(model_id, host: "localhost", port: PORTS[:llama_cpp],
                        max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates a model connected to an MLX-LM server.
          #
          # MLX-LM is an inference engine optimized for Apple Silicon (M1/M2/M3 chips).
          # It provides an OpenAI-compatible API endpoint for running quantized models
          # efficiently on Mac hardware.
          #
          # @param model_id [String] Model identifier (Hugging Face model path)
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 8080 (MLX-LM's default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.mlx_lm("mlx-community/Meta-Llama-3-8B")
          #
          # @see https://github.com/ml-explore/mlx-lm MLX-LM repository
          def mlx_lm(model_id, host: "localhost", port: PORTS[:mlx_lm],
                     max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates a model connected to a vLLM server.
          #
          # vLLM is a high-throughput inference engine designed for production
          # deployments. It provides an OpenAI-compatible API with advanced features
          # like continuous batching and PagedAttention.
          #
          # @param model_id [String] Model identifier (Hugging Face model path)
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 8000 (vLLM's default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.vllm("meta-llama/Llama-2-70b-hf")
          #
          # @see https://docs.vllm.ai vLLM documentation
          def vllm(model_id, host: "localhost", port: PORTS[:vllm],
                   max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates a model connected to a Text Generation WebUI server.
          #
          # Text Generation WebUI (oobabooga) is a feature-rich web interface for
          # running local LLMs with various backends. It provides an OpenAI-compatible
          # API when the API extension is enabled.
          #
          # @param model_id [String] Model identifier as loaded in the WebUI
          # @param host [String] Server hostname. Default: "localhost"
          # @param port [Integer] Server port. Default: 5000 (WebUI's API default)
          # @param max_tokens [Integer] Maximum response tokens. Default: 8192.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Basic usage
          #   model = OpenAIModel.text_generation_webui("TheBloke/Mistral-7B-v0.1-GPTQ")
          #
          # @see https://github.com/oobabooga/text-generation-webui Text Generation WebUI repository
          def text_generation_webui(model_id, host: "localhost", port: PORTS[:text_generation_webui],
                                    max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end
        end
      end
    end
  end
end
