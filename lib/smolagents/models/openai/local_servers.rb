module Smolagents
  module Models
    module OpenAI
      # Factory methods for local inference servers.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for popular local inference servers.
      #
      # @example
      #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
      #   model = OpenAIModel.ollama("llama3", port: 11435)
      #   model = OpenAIModel.llama_cpp("mistral-7b")
      module LocalServers
        # Default max tokens for local models to prevent runaway generation.
        # Some models (especially "thinking" variants) can get stuck in loops.
        # Users can override with max_tokens: param.
        DEFAULT_MAX_TOKENS = 8192

        # Default ports for popular local inference servers.
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
        module ClassMethods
          # Creates model for LM Studio server.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def lm_studio(model_id, host: "localhost", port: PORTS[:lm_studio],
                        max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates model for Ollama server.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def ollama(model_id, host: "localhost", port: PORTS[:ollama],
                     max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates model for llama.cpp server.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def llama_cpp(model_id, host: "localhost", port: PORTS[:llama_cpp],
                        max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates model for MLX-LM server.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def mlx_lm(model_id, host: "localhost", port: PORTS[:mlx_lm],
                     max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates model for vLLM server.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def vllm(model_id, host: "localhost", port: PORTS[:vllm],
                   max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end

          # Creates model for Text Generation WebUI.
          # @param model_id [String] Model identifier
          # @param host [String] Server hostname
          # @param port [Integer] Server port
          # @param max_tokens [Integer] Max response tokens (default: 2048)
          # @return [OpenAIModel]
          def text_generation_webui(model_id, host: "localhost", port: PORTS[:text_generation_webui],
                                    max_tokens: DEFAULT_MAX_TOKENS, **)
            new(model_id:, api_base: "http://#{host}:#{port}/v1", api_key: "not-needed", max_tokens:, **)
          end
        end
      end
    end
  end
end
