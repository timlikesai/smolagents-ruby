module Smolagents
  module Models
    module LiteLLM
      # Backend model creation for LiteLLMModel.
      #
      # Creates the appropriate backend model (OpenAIModel, AnthropicModel, etc.)
      # based on the detected provider. Handles provider-specific configuration.
      #
      # @see LiteLLMModel Main model class
      # @see ProviderRouting Provider detection
      module BackendFactory
        # @return [String] Default Azure API version
        AZURE_API_VERSION = "2024-02-15-preview".freeze

        private

        # Creates the appropriate backend model for a provider.
        #
        # @param provider [String] The provider name
        # @param resolved_model [String] The model identifier without provider prefix
        # @param kwargs [Hash] Options passed to the backend model
        # @return [Model] The configured backend model
        def create_backend(provider, resolved_model, **)
          case provider
          when "anthropic"
            AnthropicModel.new(model_id: resolved_model, **)
          when "azure"
            create_azure_backend(resolved_model, **)
          else
            create_openai_backend(provider, resolved_model, **)
          end
        end

        # Creates an OpenAI or local server backend.
        #
        # @param provider [String] The provider name
        # @param resolved_model [String] The model identifier
        # @param kwargs [Hash] Options for OpenAIModel
        # @return [OpenAIModel] Configured OpenAI model
        def create_openai_backend(provider, resolved_model, **)
          method_name = local_server_method(provider)
          if method_name
            OpenAIModel.public_send(method_name, resolved_model, **)
          else
            OpenAIModel.new(model_id: resolved_model, **)
          end
        end

        # Creates an Azure OpenAI backend with Azure-specific configuration.
        #
        # @param resolved_model [String] The deployment name
        # @param api_base [String] Azure endpoint URL
        # @param api_version [String] Azure API version
        # @param api_key [String, nil] Azure API key
        # @param kwargs [Hash] Additional options
        # @return [OpenAIModel] Configured for Azure
        def create_azure_backend(resolved_model, api_base:, api_version: AZURE_API_VERSION, api_key: nil, **)
          azure_key = api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
          azure_base = api_base.chomp("/")
          uri_base = "#{azure_base}/openai/deployments/#{resolved_model}"

          OpenAIModel.new(
            model_id: resolved_model,
            api_key: azure_key,
            api_base: uri_base,
            azure_api_version: api_version,
            **
          )
        end
      end
    end
  end
end
