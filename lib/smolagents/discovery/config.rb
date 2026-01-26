module Smolagents
  module Discovery
    # Deep freezes nested hashes/arrays for immutable constants.
    def self.deep_freeze(obj)
      case obj
      when Hash then obj.transform_values { |v| deep_freeze(v) }.freeze
      when Array then obj.map { |v| deep_freeze(v) }.freeze
      when String then obj.freeze
      else obj
      end
    end

    # Known local inference server configurations.
    LOCAL_SERVERS = deep_freeze(
      lm_studio: {
        name: "LM Studio",
        ports: [1234],
        v1_path: "/v1/models",
        v0_path: "/api/v0/models",
        api_v1_path: "/api/v1/models",
        docs: "https://lmstudio.ai/docs"
      },
      ollama: {
        name: "Ollama",
        ports: [11_434],
        v1_path: "/v1/models",
        api_path: "/api/tags",
        docs: "https://ollama.ai/docs"
      },
      llama_cpp: {
        name: "llama.cpp",
        ports: [8080],
        v1_path: "/v1/models",
        docs: "https://github.com/ggerganov/llama.cpp/tree/master/examples/server"
      },
      vllm: {
        name: "vLLM",
        ports: [8000],
        v1_path: "/v1/models",
        docs: "https://docs.vllm.ai"
      },
      mlx_lm: {
        name: "MLX-LM",
        ports: [8080],
        v1_path: "/v1/models",
        docs: "https://github.com/ml-explore/mlx-examples/tree/main/llms/mlx_lm"
      },
      openai_compatible: {
        name: "OpenAI-compatible",
        ports: [],
        v1_path: "/v1/models",
        docs: "https://platform.openai.com/docs/api-reference"
      }
    )

    # Cloud provider configurations with their environment variables.
    CLOUD_PROVIDERS = deep_freeze(
      openai: { name: "OpenAI", env_var: "OPENAI_API_KEY", docs: "https://platform.openai.com/docs" },
      anthropic: { name: "Anthropic", env_var: "ANTHROPIC_API_KEY", docs: "https://docs.anthropic.com" },
      openrouter: { name: "OpenRouter", env_var: "OPENROUTER_API_KEY", docs: "https://openrouter.ai/docs" },
      groq: { name: "Groq", env_var: "GROQ_API_KEY", docs: "https://console.groq.com/docs" },
      together: { name: "Together AI", env_var: "TOGETHER_API_KEY", docs: "https://docs.together.ai" },
      fireworks: { name: "Fireworks AI", env_var: "FIREWORKS_API_KEY", docs: "https://docs.fireworks.ai" },
      deepinfra: { name: "DeepInfra", env_var: "DEEPINFRA_API_KEY", docs: "https://deepinfra.com/docs" }
    )

    # Code examples for cloud providers.
    CLOUD_CODE_EXAMPLES = deep_freeze(
      openai: 'model = Smolagents::OpenAIModel.new(model_id: "gpt-4-turbo")',
      anthropic: 'model = Smolagents::AnthropicModel.new(model_id: "claude-sonnet-4-5-20251101")',
      openrouter: 'model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")',
      groq: 'model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile")',
      together: 'model = Smolagents::OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")',
      fireworks: 'model = Smolagents::OpenAIModel.fireworks("accounts/fireworks/models/llama-v3-70b-instruct")',
      deepinfra: 'model = Smolagents::OpenAIModel.deepinfra("meta-llama/Meta-Llama-3.1-70B-Instruct")'
    )
  end
end
