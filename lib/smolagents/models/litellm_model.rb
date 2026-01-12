module Smolagents
  class LiteLLMModel < Model
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

    attr_reader :provider, :backend

    def initialize(model_id:, **kwargs)
      super
      @provider, @resolved_model = parse_model_id(model_id)
      @kwargs = kwargs
      @backend = create_backend(@provider, @resolved_model, **kwargs)
    end

    def generate(...)
      @backend.generate(...)
    end

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
