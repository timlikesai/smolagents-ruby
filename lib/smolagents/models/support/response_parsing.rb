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
        # Validates response for errors and uses a block to extract provider-specific content.
        # The block must return [content, tool_calls, token_usage].
        #
        # @param response [Hash] Raw API response from provider
        # @param provider [String] Provider name for error messages (e.g., "OpenAI", "Anthropic")
        # @yield [Hash] Block that extracts [content, tool_calls, token_usage] from response
        # @return [ChatMessage] Parsed assistant message with raw response attached
        # @raise [AgentGenerationError] When response contains an error field
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
        # @raise [AgentGenerationError] When response["error"] exists
        def check_response_error(response, provider:)
          return unless (error = response["error"])

          raise Smolagents::AgentGenerationError, "#{provider} error: #{error["message"]}"
        end

        # Parses token usage from standard format.
        #
        # Extracts input and output token counts using provider-specific key names.
        #
        # @param usage [Hash, nil] Usage hash from API (nil returns nil)
        # @param input_key [String] Key name for input tokens in usage hash
        # @param output_key [String] Key name for output tokens in usage hash
        # @return [TokenUsage, nil] Parsed TokenUsage object or nil if usage is nil
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
