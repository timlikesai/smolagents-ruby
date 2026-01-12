module Smolagents
  module CLI
    module ModelBuilder
      PROVIDERS = {
        openai: ->(opts) { Smolagents::OpenAIModel.new(**opts) },
        anthropic: ->(opts) { Smolagents::AnthropicModel.new(**opts) }
      }.freeze

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
