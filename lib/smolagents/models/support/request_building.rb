module Smolagents
  module Models
    module ModelSupport
      # Common request parameter building for model implementations.
      #
      # Provides the core parameter building pattern that all model adapters
      # share. Provider-specific message and tool formatting are implemented
      # in the including module.
      #
      # @example Usage in a model
      #   include ModelSupport::RequestBuilding
      #
      #   def build_params(messages, **options)
      #     build_base_params(
      #       messages:, temperature: options[:temperature],
      #       max_tokens: options[:max_tokens], tools: options[:tools]
      #     ).merge(provider_specific_params(messages))
      #   end
      module RequestBuilding
        # Builds common request parameters.
        #
        # @param messages [Array<ChatMessage>] Conversation messages
        # @param temperature [Float, nil] Override temperature
        # @param max_tokens [Integer, nil] Override max tokens
        # @param tools [Array<Tool>, nil] Available tools
        # @return [Hash] Base request parameters
        def build_base_params(messages:, temperature:, max_tokens:, tools: nil)
          {
            model: model_id,
            messages: format_messages(messages),
            temperature: temperature || @temperature,
            max_tokens: max_tokens || @max_tokens,
            tools: tools && format_tools(tools)
          }.compact
        end

        # Merges optional parameters into request hash.
        #
        # @param base [Hash] Base parameters
        # @param extras [Hash] Additional parameters to merge
        # @return [Hash] Merged parameters (nil values removed)
        def merge_params(base, extras)
          base.merge(extras).compact
        end
      end
    end
  end
end
