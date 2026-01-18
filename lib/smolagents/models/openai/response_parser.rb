require_relative "../support"

module Smolagents
  module Models
    module OpenAI
      # Response parsing for OpenAI API responses.
      #
      # Handles conversion of raw API responses into ChatMessage objects,
      # including tool call extraction and token usage parsing.
      module ResponseParser
        include ModelSupport::ResponseParsing

        # Parses OpenAI API response into a ChatMessage.
        #
        # @param response [Hash] Raw API response
        # @return [ChatMessage] Parsed assistant message
        # @raise [AgentGenerationError] On API error response
        def parse_response(response)
          parse_chat_response(response, provider: "OpenAI") do |resp|
            message = resp.dig("choices", 0, "message") || {}
            [
              message["content"] || "",
              parse_tool_calls(message["tool_calls"]),
              extract_openai_usage(resp)
            ]
          end
        end

        private

        def extract_openai_usage(response)
          parse_token_usage(response["usage"], input_key: "prompt_tokens", output_key: "completion_tokens")
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
