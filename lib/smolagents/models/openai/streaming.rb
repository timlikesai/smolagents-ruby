module Smolagents
  module Models
    module OpenAI
      # Streaming response handling for OpenAI API.
      #
      # Provides streaming generation support with chunk parsing
      # and Enumerator-based lazy evaluation.
      module Streaming
        # Generates a streaming response from the OpenAI API.
        #
        # Opens a streaming connection and yields ChatMessage chunks as they arrive.
        # Useful for real-time display and reducing perceived latency.
        #
        # @param messages [Array<ChatMessage>] The conversation history
        # @param options [Hash] Additional options (temperature, max_tokens, etc.)
        #
        # @yield [ChatMessage] Each streaming chunk as a partial ChatMessage with
        #   content containing the delta text
        #
        # @return [Enumerator<ChatMessage>] When no block given, returns an Enumerator
        #   for lazy evaluation and chaining
        #
        # @example Streaming with a block
        #   model.generate_stream(messages) do |chunk|
        #     print chunk.content
        #   end
        #
        # @example Collecting all chunks
        #   full_response = model.generate_stream(messages)
        #     .map(&:content)
        #     .compact
        #     .join
        def generate_stream(messages, **, &block)
          return enum_for(:generate_stream, messages, **) unless block

          params = build_stream_params(messages)
          with_circuit_breaker("openai_api") do
            @client.chat(parameters: params) { |chunk, _| yield_stream_chunk(chunk, &block) }
          end
        end

        private

        def build_stream_params(messages)
          { model: model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
        end

        def yield_stream_chunk(chunk)
          delta = chunk.dig("choices", 0, "delta")
          return unless delta

          yield Smolagents::ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk)
        rescue StandardError
          nil
        end
      end
    end
  end
end
