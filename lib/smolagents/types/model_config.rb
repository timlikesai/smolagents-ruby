module Smolagents
  module Types
    # Unified configuration for LLM model instances.
    #
    # ModelConfig provides a standardized way to configure any model implementation
    # (OpenAI, Anthropic, local servers, etc.) with consistent parameter handling.
    # It uses Data.define for immutability and pattern matching support.
    #
    # == Core Parameters
    #
    # - +:model_id+ - Required model identifier (e.g., "gpt-4", "claude-3-opus")
    # - +:api_key+ - API key for authentication (falls back to ENV vars)
    # - +:api_base+ - Custom API endpoint URL (for local servers or proxies)
    # - +:temperature+ - Sampling temperature (0.0-2.0, default: 0.7)
    # - +:max_tokens+ - Maximum response tokens (nil uses provider default)
    #
    # == Provider-Specific Parameters
    #
    # - +:azure_api_version+ - Azure OpenAI API version string
    # - +:timeout+ - Request timeout in seconds
    # - +:extras+ - Provider-specific options hash
    #
    # @example Basic configuration
    #   config = ModelConfig.create(model_id: "gpt-4", api_key: "sk-...")
    #   model = OpenAIModel.new(config:)
    #
    # @example Local model configuration
    #   config = ModelConfig.create(
    #     model_id: "gemma-3n-e4b-it-q8_0",
    #     api_base: "http://localhost:1234/v1",
    #     api_key: "not-needed",
    #     max_tokens: 2048
    #   )
    #
    # @example Anthropic configuration
    #   config = ModelConfig.create(
    #     model_id: "claude-3-opus-20240229",
    #     api_key: ENV["ANTHROPIC_API_KEY"],
    #     max_tokens: 4096,
    #     temperature: 0.5
    #   )
    #
    # @see Model Base model class
    # @see OpenAIModel OpenAI implementation
    # @see AnthropicModel Anthropic implementation
    ModelConfig = Data.define(
      :model_id,
      :api_key,
      :api_base,
      :temperature,
      :max_tokens,
      :azure_api_version,
      :timeout,
      :extras
    ) do
      # Default temperature for LLM requests.
      # Provides a balance between creativity and consistency.
      DEFAULT_TEMPERATURE = 0.7

      # Creates a ModelConfig with specified options.
      #
      # All parameters except model_id are optional with sensible defaults.
      #
      # @param model_id [String] Required model identifier
      # @param api_key [String, nil] API key (defaults to provider ENV var)
      # @param api_base [String, nil] Custom API endpoint URL
      # @param temperature [Float] Sampling temperature (default: 0.7)
      # @param max_tokens [Integer, nil] Maximum tokens in response
      # @param azure_api_version [String, nil] Azure API version
      # @param timeout [Integer, nil] Request timeout in seconds
      # @param extras [Hash] Additional provider-specific options
      # @return [ModelConfig]
      #
      # @example
      #   config = ModelConfig.create(
      #     model_id: "gpt-4-turbo",
      #     temperature: 0.5,
      #     max_tokens: 4096
      #   )
      def self.create(
        model_id:,
        api_key: nil,
        api_base: nil,
        temperature: DEFAULT_TEMPERATURE,
        max_tokens: nil,
        azure_api_version: nil,
        timeout: nil,
        **extras
      )
        new(
          model_id:,
          api_key:,
          api_base:,
          temperature:,
          max_tokens:,
          azure_api_version:,
          timeout:,
          extras: extras.freeze
        )
      end

      # Returns a new config with the specified changes.
      #
      # @param options [Hash] Fields to change
      # @return [ModelConfig] New config with changes applied
      #
      # @example
      #   config = ModelConfig.create(model_id: "gpt-4")
      #   updated = config.with(temperature: 0.9)
      def with(**)
        self.class.new(**to_h, **)
      end

      # Converts config to keyword arguments for model initialization.
      #
      # Filters out nil values and flattens extras into the hash.
      # This format is suitable for passing directly to model constructors.
      #
      # @return [Hash] Keyword arguments for model initialization
      #
      # @example
      #   config.to_model_args
      #   # => { model_id: "gpt-4", temperature: 0.7, api_key: "sk-..." }
      def to_model_args
        {
          model_id:,
          api_key:,
          api_base:,
          temperature:,
          max_tokens:,
          azure_api_version:,
          timeout:
        }.compact.merge(extras || {})
      end

      # Checks if this config is for a local server.
      #
      # @return [Boolean] True if api_base points to localhost
      def local? = (api_base&.include?("localhost") || api_base&.include?("127.0.0.1")) || false

      # Checks if this config is for Azure OpenAI.
      #
      # @return [Boolean] True if azure_api_version is set
      def azure? = !azure_api_version.nil?

      # Pattern matching support.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract
      # @return [Hash] Hash with requested keys
      def deconstruct_keys(_keys)
        {
          model_id:,
          api_key:,
          api_base:,
          temperature:,
          max_tokens:,
          azure_api_version:,
          timeout:,
          extras:
        }
      end
    end
  end
end
