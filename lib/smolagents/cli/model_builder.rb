module Smolagents
  module CLI
    # Model builder mixin for CLI command classes.
    #
    # Provides factory methods for creating model instances from various providers.
    # Supports OpenAI, Anthropic, and local API-compatible models with flexible
    # configuration options.
    #
    # This module is designed to be included in Thor command classes and accessed
    # via the commands that include this mixin.
    #
    # @example Using with a CLI command
    #   class MyCLI < Thor
    #     include Smolagents::CLI::ModelBuilder
    #
    #     def my_command
    #       model = build_model(
    #         provider: "openai",
    #         model_id: "gpt-4"
    #       )
    #     end
    #   end
    #
    # @see Main
    # @see Commands
    module ModelBuilder
      # Supported model providers and their corresponding factory lambdas.
      #
      # Maps provider names to factory functions that instantiate the appropriate
      # model class with the given options.
      #
      # @return [Hash{Symbol => Proc}] Provider factory mappings
      PROVIDERS = {
        openai: ->(opts) { Smolagents::OpenAIModel.new(**opts) },
        anthropic: ->(opts) { Smolagents::AnthropicModel.new(**opts) }
      }.freeze

      # Builds a model instance from the specified provider.
      #
      # Factory method that creates an appropriate model instance based on the provider
      # name. Constructs model options from provided parameters and delegates to the
      # provider-specific factory function.
      #
      # Supported providers: openai, anthropic
      #
      # @param provider [String, Symbol] The model provider identifier (openai, anthropic)
      # @param model_id [String] The model identifier (e.g., "gpt-4", "claude-3-5-sonnet-20241022")
      # @param api_key [String, nil] Optional API key (defaults to environment variable if not provided)
      # @param api_base [String, nil] Optional custom API base URL for local models
      # @return [OpenAIModel, AnthropicModel] The constructed model instance
      # @raise [Thor::Error] If the provider is not in the PROVIDERS registry
      #
      # @example Build an OpenAI model
      #   model = build_model(provider: "openai", model_id: "gpt-4")
      #
      # @example Build an Anthropic model
      #   model = build_model(provider: "anthropic", model_id: "claude-3-5-sonnet-20241022")
      #
      # @example Use a local model with custom API base
      #   model = build_model(
      #     provider: "openai",
      #     model_id: "local-model",
      #     api_base: "http://localhost:1234/v1"
      #   )
      #
      # @example Provide explicit API key
      #   model = build_model(
      #     provider: "openai",
      #     model_id: "gpt-4",
      #     api_key: "sk-..."
      #   )
      #
      # @note Provider names are case-insensitive and converted to symbols
      # @see OpenAIModel
      # @see AnthropicModel
      # @see PROVIDERS
      def build_model(provider:, model_id:, api_key: nil, api_base: nil)
        model_opts = { model_id: }.tap do |opts|
          opts[:api_key] = api_key if api_key
          opts[:api_base] = api_base if api_base
        end
        PROVIDERS.fetch(provider.to_sym) { raise Thor::Error, "Unknown provider: #{provider}" }.call(model_opts)
      end
    end
  end
end
