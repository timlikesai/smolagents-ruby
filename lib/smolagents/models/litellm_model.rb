module Smolagents
  # Multi-provider model router supporting 100+ LLM backends.
  #
  # LiteLLMModel provides a unified interface for routing requests to various
  # LLM providers using a simple "provider/model" format. It automatically
  # creates the appropriate backend model (OpenAIModel, AnthropicModel, etc.)
  # based on the model_id prefix.
  #
  # Supported providers:
  # - `openai/` - OpenAI models (default if no prefix)
  # - `anthropic/` - Anthropic Claude models
  # - `azure/` - Azure OpenAI Service
  # - `ollama/` - Ollama local models
  # - `lm_studio/` - LM Studio local server
  # - `llama_cpp/` - llama.cpp server
  # - `mlx_lm/` - MLX LM server (Apple Silicon)
  # - `vllm/` - vLLM server
  #
  # @example LM Studio local model (recommended)
  #   model = LiteLLMModel.new(model_id: "lm_studio/gemma-3n-e4b-it-q8_0")
  #
  # @example llama.cpp with GPT-OSS
  #   model = LiteLLMModel.new(model_id: "llama_cpp/gpt-oss-20b-mxfp4")
  #
  # @example Ollama local model
  #   model = LiteLLMModel.new(model_id: "ollama/nemotron-3-nano-30b-a3b-iq4_nl")
  #
  # @example Anthropic Claude 4.5
  #   model = LiteLLMModel.new(model_id: "anthropic/claude-sonnet-4-5-20251101")
  #
  # @example Google Gemini 3
  #   model = LiteLLMModel.new(model_id: "gemini/gemini-3-pro")
  #
  # @see Model Base class documentation
  # @see OpenAIModel Backend for OpenAI-compatible providers
  # @see AnthropicModel Backend for Anthropic provider
  class LiteLLMModel < Model
    # @return [Hash{String => Symbol}] Supported provider prefixes
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

    # @return [String] The detected provider name
    attr_reader :provider

    # @return [Model] The backend model handling API calls
    attr_reader :backend

    # Creates a new LiteLLM model router.
    #
    # @param model_id [String] Model identifier with optional provider prefix
    #   (e.g., "gpt-4", "openai/gpt-4", "anthropic/claude-3-opus")
    # @param kwargs [Hash] Provider-specific options passed to the backend model
    # @example
    #   LiteLLMModel.new(model_id: "anthropic/claude-3-opus", api_key: "...")
    def initialize(model_id:, **kwargs)
      super
      @provider, @resolved_model = parse_model_id(model_id)
      @kwargs = kwargs
      @backend = create_backend(@provider, @resolved_model, **kwargs)
    end

    # Generates a response by delegating to the appropriate backend model.
    #
    # @param args [Array] Arguments passed to the backend's generate method
    # @return [ChatMessage] The assistant's response
    # @see Model#generate
    def generate(...)
      @backend.generate(...)
    end

    # Generates a streaming response by delegating to the backend model.
    #
    # @param args [Array] Arguments passed to the backend's generate_stream method
    # @yield [ChatMessage] Each chunk of the streaming response
    # @return [Enumerator<ChatMessage>] When no block given
    # @see Model#generate_stream
    def generate_stream(...)
      @backend.generate_stream(...)
    end

    private

    def parse_model_id(model_id)
      parts = model_id.split("/", 2)
      if parts.length == 2 && PROVIDERS.key?(parts[0])
        [parts[0], parts[1]]
      else
        ["openai", model_id]
      end
    end

    def create_backend(provider, resolved_model, **)
      case provider
      when "anthropic"
        AnthropicModel.new(model_id: resolved_model, **)
      when "azure"
        create_azure_backend(resolved_model, **)
      when "ollama"
        OpenAIModel.ollama(resolved_model, **)
      when "lm_studio"
        OpenAIModel.lm_studio(resolved_model, **)
      when "llama_cpp"
        OpenAIModel.llama_cpp(resolved_model, **)
      when "mlx_lm"
        OpenAIModel.mlx_lm(resolved_model, **)
      when "vllm"
        OpenAIModel.vllm(resolved_model, **)
      else
        OpenAIModel.new(model_id: resolved_model, **)
      end
    end

    def create_azure_backend(resolved_model, api_base:, api_version: "2024-02-15-preview", api_key: nil, **)
      azure_key = api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
      azure_base = api_base.chomp("/")

      uri_base = "#{azure_base}/openai/deployments/#{resolved_model}"

      OpenAIModel.new(
        model_id: resolved_model,
        api_key: azure_key,
        api_base: uri_base,
        **,
        azure_api_version: api_version
      )
    end
  end
end
