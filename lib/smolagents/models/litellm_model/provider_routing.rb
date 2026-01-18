module Smolagents
  module Models
    module LiteLLM
      # Provider parsing and routing logic for LiteLLMModel.
      #
      # Handles parsing of model_id strings to determine which provider
      # should handle the request. Supports the "provider/model" format.
      #
      # @example Provider parsing
      #   parse_model_id("anthropic/claude-3")  #=> ["anthropic", "claude-3"]
      #   parse_model_id("gpt-4")               #=> ["openai", "gpt-4"]
      #
      # @see LiteLLMModel Main model class
      module ProviderRouting
        # @return [Hash{String => Symbol}] Supported provider prefixes.
        PROVIDERS = {
          "openai" => :openai,
          "anthropic" => :anthropic,
          "azure" => :azure,
          "ollama" => :ollama,
          "lm_studio" => :lm_studio,
          "llama_cpp" => :llama_cpp,
          "mlx_lm" => :mlx_lm,
          "vllm" => :vllm
        }.freeze

        # @return [Hash{String => Symbol}] Maps local server providers to OpenAIModel factory methods.
        LOCAL_SERVERS = {
          "ollama" => :ollama,
          "lm_studio" => :lm_studio,
          "llama_cpp" => :llama_cpp,
          "mlx_lm" => :mlx_lm,
          "vllm" => :vllm
        }.freeze

        private

        # Parses model_id into provider and resolved model name.
        #
        # @param model_id [String] Model identifier with optional provider prefix
        # @return [Array<String>] Two-element array: [provider, resolved_model]
        def parse_model_id(model_id)
          parts = model_id.split("/", 2)
          if parts.length == 2 && PROVIDERS.key?(parts[0])
            [parts[0], parts[1]]
          else
            ["openai", model_id]
          end
        end

        # Determines if a provider uses a local OpenAI-compatible server.
        #
        # @param provider [String] The provider name
        # @return [Boolean] True if provider is a local server
        def local_server?(provider) = LOCAL_SERVERS.key?(provider)

        # Gets the factory method name for a local server provider.
        #
        # @param provider [String] The provider name
        # @return [Symbol, nil] Factory method name or nil
        def local_server_method(provider) = LOCAL_SERVERS[provider]
      end
    end
  end
end
