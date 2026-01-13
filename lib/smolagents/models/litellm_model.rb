module Smolagents
  module Models
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
      # @!attribute [r] PROVIDERS
      #   @return [Hash{String => Symbol}] Supported provider prefixes and their internal identifiers.
      #     Maps provider string prefixes to their handling implementations:
      #     - "openai" => :openai (OpenAI cloud API)
      #     - "anthropic" => :anthropic (Anthropic Claude)
      #     - "azure" => :azure (Azure OpenAI Service)
      #     - "ollama" => :ollama (Ollama local server)
      #     - "lm_studio" => :lm_studio (LM Studio local server)
      #     - "llama_cpp" => :llama_cpp (llama.cpp server)
      #     - "mlx_lm" => :mlx_lm (MLX LM server for Apple Silicon)
      #     - "vllm" => :vllm (vLLM high-throughput server)
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

      # @!attribute [r] provider
      #   @return [String] The detected provider name from the model_id prefix.
      #     Value is one of: "openai", "anthropic", "azure", "ollama", "lm_studio",
      #     "llama_cpp", "mlx_lm", "vllm", or defaults to "openai" if no prefix provided.
      attr_reader :provider

      # @!attribute [r] backend
      #   @return [Model] The backend model instance (OpenAIModel, AnthropicModel, etc.)
      #     that handles actual API communication. Created based on the detected provider.
      attr_reader :backend

      # Creates a new LiteLLM model router.
      #
      # LiteLLMModel provides a unified interface for routing requests to various
      # LLM providers using a "provider/model" naming convention. It parses the
      # model_id prefix, creates the appropriate backend model, and delegates all
      # API calls to it.
      #
      # This allows switching providers by changing just the model_id string,
      # enabling easy experimentation across different backends without code changes.
      #
      # @param model_id [String] Model identifier with optional provider prefix:
      #   - "gpt-4" or "openai/gpt-4" => OpenAI GPT-4
      #   - "anthropic/claude-opus-4-5-20251101" => Anthropic Claude
      #   - "azure/gpt-4" => Azure OpenAI (requires api_base, api_version)
      #   - "ollama/nemotron-3-nano-30b-a3b-iq4_nl" => Ollama
      #   - "lm_studio/gemma-3n-e4b-it-q8_0" => LM Studio
      #   - "llama_cpp/gpt-oss-20b-mxfp4" => llama.cpp
      #   - "mlx_lm/mlx-community/Meta-Llama-3-8B" => MLX LM (Apple Silicon)
      #   - "vllm/meta-llama/Llama-2-70b" => vLLM
      #
      # @param kwargs [Hash] Provider-specific options passed to the backend model:
      #   - api_key [String] Provider API key (environment variable fallback supported)
      #   - api_base [String] Base URL for local servers or Azure endpoint
      #   - temperature [Float] Sampling temperature (provider-specific range)
      #   - max_tokens [Integer] Maximum output tokens
      #   - For Azure: api_version [String] Azure API version (default: "2024-02-15-preview")
      #   - Other provider-specific options
      #
      # @raise [Smolagents::GemLoadError] When required gem for backend is missing
      #   (e.g., ruby-openai for OpenAI, ruby-anthropic for Anthropic)
      #
      # @example OpenAI routing (default provider if no prefix)
      #   model = LiteLLMModel.new(model_id: "gpt-4")
      #   response = model.generate([ChatMessage.user("Hello")])
      #
      # @example Anthropic routing
      #   model = LiteLLMModel.new(
      #     model_id: "anthropic/claude-opus-4-5-20251101",
      #     api_key: ENV["ANTHROPIC_API_KEY"]
      #   )
      #
      # @example Local Ollama routing
      #   model = LiteLLMModel.new(
      #     model_id: "ollama/nemotron-3-nano-30b-a3b-iq4_nl",
      #     api_base: "http://localhost:11434"
      #   )
      #
      # @example Azure OpenAI routing
      #   model = LiteLLMModel.new(
      #     model_id: "azure/gpt-4",
      #     api_base: "https://myresource.openai.azure.com",
      #     api_version: "2024-02-15-preview",
      #     api_key: ENV["AZURE_OPENAI_API_KEY"]
      #   )
      #
      # @example LM Studio routing (recommended for local development)
      #   model = LiteLLMModel.new(
      #     model_id: "lm_studio/gemma-3n-e4b-it-q8_0",
      #     api_base: "http://localhost:1234/v1"
      #   )
      #
      # @example Easy provider switching
      #   # Configuration
      #   config = {
      #     model_id: ENV.fetch("LLM_MODEL_ID", "lm_studio/gemma-3n-e4b-it-q8_0"),
      #     api_key: ENV["OPENAI_API_KEY"],
      #     temperature: 0.7
      #   }
      #   # Works with any configured provider
      #   model = LiteLLMModel.new(**config)
      #
      # @see #generate For generating responses
      # @see #generate_stream For streaming responses
      # @see OpenAIModel Backend for OpenAI-compatible providers
      # @see AnthropicModel Backend for Anthropic provider
      # @see Model#initialize Parent class initialization
      def initialize(model_id:, **kwargs)
        super
        @provider, @resolved_model = parse_model_id(model_id)
        @kwargs = kwargs
        @backend = create_backend(@provider, @resolved_model, **kwargs)
      end

      # Generates a response by delegating to the appropriate backend model.
      #
      # This method acts as a transparent proxy, forwarding all arguments to the
      # backend model's generate method. The backend is determined by the provider
      # prefix in the model_id provided at initialization.
      #
      # All features supported by the backend model are available, including:
      # - Tool/function calling
      # - Streaming responses
      # - Vision/image support (if backend supports it)
      # - Token usage tracking
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param stop_sequences [Array<String>, nil] Sequences that stop generation
      # @param temperature [Float, nil] Sampling temperature override
      # @param max_tokens [Integer, nil] Maximum output tokens override
      # @param tools_to_call_from [Array<Tool>, nil] Available tools for function calling
      # @param response_format [Hash, nil] Structured output format (backend-dependent)
      # @param kwargs [Hash] Additional backend-specific options
      #
      # @return [ChatMessage] The assistant's response message
      #
      # @raise [AgentGenerationError] When the backend API returns an error
      # @raise [Faraday::Error] When network error occurs
      #
      # @example Basic usage delegates to backend
      #   model = LiteLLMModel.new(model_id: "openai/gpt-4")
      #   response = model.generate([ChatMessage.user("Hello")])
      #   # Calls OpenAIModel#generate internally
      #
      # @example Backend capabilities are preserved
      #   model = LiteLLMModel.new(
      #     model_id: "anthropic/claude-opus-4-5-20251101"
      #   )
      #   tools = [WeatherTool.new]
      #   response = model.generate(messages, tools_to_call_from: tools)
      #   # Calls AnthropicModel#generate with tool support
      #
      # @see Model#generate Base class definition
      # @see #generate_stream For streaming responses
      def generate(...)
        @backend.generate(...)
      end

      # Generates a streaming response by delegating to the backend model.
      #
      # Establishes a streaming connection through the appropriate backend and
      # yields response chunks as they arrive. This transparent delegation allows
      # streaming to work with any supported provider.
      #
      # @param messages [Array<ChatMessage>] The conversation history
      # @param kwargs [Hash] Additional backend-specific options
      #
      # @yield [ChatMessage] Each streaming chunk from the backend
      #
      # @return [Enumerator<ChatMessage>] When no block given, returns an Enumerator
      #
      # @example Streaming with block
      #   model = LiteLLMModel.new(model_id: "openai/gpt-4")
      #   model.generate_stream(messages) do |chunk|
      #     print chunk.content
      #   end
      #
      # @example Streaming as Enumerator
      #   model = LiteLLMModel.new(model_id: "anthropic/claude-opus-4-5-20251101")
      #   full_text = model.generate_stream(messages)
      #     .map(&:content)
      #     .join
      #
      # @see Model#generate_stream Base class definition
      # @see #generate For non-streaming generation
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
end
