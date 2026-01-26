module Smolagents
  module Models
    module ModelSupport
      # Template method pattern for the generate flow.
      #
      # Provides a consistent structure for model generation that includes
      # instrumentation, API calling, and response parsing. Subclasses
      # implement the specific steps.
      #
      # @example Usage in a model
      #   include ModelSupport::GenerateTemplate
      #
      #   def generate(messages, **options)
      #     generate_with_instrumentation(messages, **options) do |params|
      #       @client.chat(parameters: params)
      #     end
      #   end
      module GenerateTemplate
        # Executes the generate flow with instrumentation.
        #
        # @param messages [Array<ChatMessage>] Conversation messages
        # @param options [Hash] Generation options
        # @yield [Hash] Block that executes the API call with params
        # @return [ChatMessage] Parsed response
        def generate_with_instrumentation(messages, **)
          instrument_generate do
            params = build_params(messages, **)
            response = yield(params)
            parse_response(response)
          end
        end

        # Wraps generation in telemetry instrumentation.
        #
        # @yield Block to instrument
        # @return [Object] Block result
        def instrument_generate(&)
          Smolagents::Instrumentation.instrument(
            "smolagents.model.generate",
            model_id:,
            model_class: self.class.name,
            &
          )
        end
      end
    end
  end
end
