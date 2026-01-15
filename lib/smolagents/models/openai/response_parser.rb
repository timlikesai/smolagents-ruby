module Smolagents
  module Models
    module OpenAI
      # Response parsing for OpenAI API responses.
      #
      # Handles conversion of raw API responses into ChatMessage objects,
      # including tool call extraction and token usage parsing.
      module ResponseParser
        # Parses OpenAI API response into a ChatMessage.
        #
        # @param response [Hash] Raw API response
        # @return [ChatMessage] Parsed assistant message
        # @raise [AgentGenerationError] On API error response
        def parse_response(response)
          handle_error_response(response)
          build_message_from_response(response)
        end

        private

        def handle_error_response(response)
          error = response["error"]
          raise Smolagents::AgentGenerationError, "OpenAI error: #{error["message"]}" if error
        end

        def build_message_from_response(response)
          message = response.dig("choices", 0, "message")
          return Smolagents::ChatMessage.assistant("") unless message

          Smolagents::ChatMessage.assistant(
            message["content"],
            tool_calls: parse_tool_calls(message["tool_calls"]),
            raw: response,
            token_usage: parse_token_usage(response["usage"])
          )
        end

        def parse_token_usage(usage)
          return nil unless usage

          Smolagents::TokenUsage.new(
            input_tokens: usage["prompt_tokens"],
            output_tokens: usage["completion_tokens"]
          )
        end

        def parse_tool_calls(raw_calls)
          raw_calls&.map do |call|
            Smolagents::ToolCall.new(
              id: call["id"],
              name: call.dig("function", "name"),
              arguments: parse_tool_arguments(call.dig("function", "arguments"))
            )
          end
        end

        def parse_tool_arguments(args)
          return args if args.is_a?(Hash)

          JSON.parse(args)
        rescue StandardError
          {}
        end
      end
    end
  end
end
