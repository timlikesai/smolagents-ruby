module Smolagents
  module Models
    module ModelSupport
      # Common response parsing patterns for model implementations.
      #
      # Provides shared error checking and response building logic that
      # all model adapters use. Submodules implement provider-specific
      # extraction via the extractor callable.
      #
      # @example Usage in a model
      #   include ModelSupport::ResponseParsing
      #
      #   def parse_response(response)
      #     parse_chat_response(response, provider: "openai") do |resp|
      #       [extract_content(resp), extract_tool_calls(resp), extract_usage(resp)]
      #     end
      #   end
      module ResponseParsing
        # Parses an API response into a ChatMessage.
        #
        # Uses a block to extract provider-specific content. The block must
        # return [content, tool_calls, token_usage].
        #
        # @param response [Hash] Raw API response
        # @param provider [String] Provider name for error messages
        # @yield [Hash] Block that extracts content from response
        # @yieldreturn [Array] [content, tool_calls, token_usage]
        # @return [ChatMessage] Parsed assistant message
        # @raise [AgentGenerationError] When response contains an error
        def parse_chat_response(response, provider:)
          check_response_error(response, provider:)
          content, tool_calls, token_usage = yield(response)

          Smolagents::ChatMessage.assistant(
            content,
            tool_calls:,
            raw: response,
            token_usage:
          )
        end

        # Checks for API error in response and raises if present.
        #
        # @param response [Hash] Raw API response
        # @param provider [String] Provider name for error context
        # @raise [AgentGenerationError] When response contains an error
        def check_response_error(response, provider:)
          return unless (error = response["error"])

          raise Smolagents::AgentGenerationError, "#{provider} error: #{error["message"]}"
        end

        # Parses token usage from standard format.
        #
        # @param usage [Hash, nil] Usage hash from API
        # @param input_key [String] Key for input tokens
        # @param output_key [String] Key for output tokens
        # @return [TokenUsage, nil] Parsed token usage or nil
        def parse_token_usage(usage, input_key:, output_key:)
          return nil unless usage

          Smolagents::TokenUsage.new(
            input_tokens: usage[input_key],
            output_tokens: usage[output_key]
          )
        end
      end
    end
  end
end
