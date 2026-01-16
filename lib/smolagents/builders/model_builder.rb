require_relative "model_builder/build"
require_relative "model_builder/callbacks"
require_relative "model_builder/reliability"
require_relative "model_builder/setters"

module Smolagents
  module Builders
    # Model type to class mapping
    MODEL_TYPES = {
      openai: "OpenAIModel",
      anthropic: "AnthropicModel",
      litellm: "LiteLLMModel",
      lm_studio: "OpenAIModel",
      ollama: "OpenAIModel",
      llama_cpp: "OpenAIModel",
      vllm: "OpenAIModel"
    }.freeze

    # Local server configurations
    LOCAL_SERVERS = {
      lm_studio: { port: 1234, host: "localhost" },
      ollama: { port: 11_434, host: "localhost" },
      llama_cpp: { port: 8080, host: "localhost" },
      vllm: { port: 8000, host: "localhost" }
    }.freeze

    # Fluent builder for composing model configurations with reliability features.
    #
    # Supports OpenAI-compatible APIs (LM Studio, Ollama, vLLM) and cloud providers.
    #
    # @example Basic model with health checking
    #   model = Smolagents.model(:openai)
    #     .id("gpt-4")
    #     .api_key(ENV["OPENAI_API_KEY"])
    #     .with_health_check
    #     .build
    #
    # @example Local model with fallback
    #   model = Smolagents.model(:lm_studio)
    #     .id("local-model")
    #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
    #     .with_retry(max_attempts: 3)
    #     .build
    #
    # @see Smolagents.model Factory method to create builders
    ModelBuilder = Data.define(:type_or_model, :configuration) do
      include Base
      include ModelBuilderBuild
      include ModelBuilderCallbacks
      include ModelBuilderReliability
      include ModelBuilderSetters

      # Default configuration.
      # @return [Hash]
      def self.default_configuration
        { callbacks: [], fallbacks: [], retry_policy: nil, circuit_breaker: nil, health_check: nil }
      end

      # Factory method to create a new builder.
      #
      # @param type_or_model [Symbol, Model] Model type or existing model
      # @return [ModelBuilder]
      def self.create(type_or_model = :openai)
        config = type_or_model.is_a?(Symbol) ? config_for_type(type_or_model) : config_for_model(type_or_model)
        new(type_or_model:, configuration: config)
      end

      def self.config_for_type(type)
        base = default_configuration.merge(type:)
        LOCAL_SERVERS.key?(type) ? base.merge(local_server_config(type)) : base
      end

      def self.local_server_config(type)
        server = LOCAL_SERVERS[type]
        { api_base: "http://#{server[:host]}:#{server[:port]}/v1", api_key: "not-needed" }
      end

      def self.config_for_model(model) = default_configuration.merge(existing_model: model)

      # Builder method registrations
      register_method :id,
                      description: "Set the model identifier",
                      required: true,
                      validates: ->(v) { v.is_a?(String) && !v.empty? }

      register_method :temperature,
                      description: "Set temperature (0.0-2.0)",
                      validates: ->(v) { v.is_a?(Numeric) && v >= 0.0 && v <= 2.0 },
                      aliases: [:temp]

      register_method :max_tokens,
                      description: "Set maximum tokens (1-100000)",
                      validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 100_000 },
                      aliases: [:tokens]

      register_method :timeout,
                      description: "Set request timeout in seconds (1-600)",
                      validates: ->(v) { v.is_a?(Numeric) && v.positive? && v <= 600 }

      register_method :api_key,
                      description: "Set API authentication key",
                      validates: ->(v) { v.is_a?(String) && !v.empty? },
                      aliases: [:key]

      # Get current configuration.
      # @return [Hash]
      def config = configuration.dup

      # Pretty print configuration.
      def inspect
        cfg = configuration
        parts = [
          cfg[:type] && "type=#{cfg[:type]}",
          cfg[:model_id] && "model_id=#{cfg[:model_id]}",
          cfg[:fallbacks].any? && "fallbacks=#{cfg[:fallbacks].size}",
          cfg[:health_check] && "health_check",
          cfg[:retry_policy] && "retry=#{cfg[:retry_policy][:max_attempts]}"
        ].compact
        "#<ModelBuilder #{parts.join(" ")}>"
      end

      private

      # Immutable update helper.
      # @param kwargs [Hash] Configuration changes
      # @return [ModelBuilder]
      def with_config(**kwargs)
        self.class.new(type_or_model:, configuration: configuration.merge(kwargs))
      end
    end
  end
end
