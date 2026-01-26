module Smolagents
  module Models
    module Anthropic
      # Streaming support for Anthropic API.
      #
      # Handles server-sent events (SSE) streaming responses
      # and chunk processing.
      module Streaming
        # Streams messages from Anthropic API.
        #
        # @param params [Hash] Request parameters for Anthropic API
        # @yield [ChatMessage] Each streaming text delta as a ChatMessage chunk
        # @return [void]
        def stream_messages(params)
          @client.messages(parameters: params) do |chunk|
            next unless text_delta_chunk?(chunk)

            yield(Smolagents::ChatMessage.assistant(chunk["delta"]["text"], raw: chunk))
          end
        end

        private

        def text_delta_chunk?(chunk)
          chunk.is_a?(Hash) &&
            chunk["type"] == "content_block_delta" &&
            chunk.dig("delta", "type") == "text_delta"
        end
      end
    end
  end
end
