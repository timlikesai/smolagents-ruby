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
        # Extracts message content, tool calls, and token usage from the API response.
        # Handles LM Studio's separated reasoning_content block for reasoning models.
        #
        # @param response [Hash] Raw API response from OpenAI
        # @return [ChatMessage] Parsed assistant message with content, tool calls, and usage
        # @raise [AgentGenerationError] On API error response
        def parse_response(response)
          parse_chat_response(response, provider: "OpenAI") do |resp|
            message = resp.dig("choices", 0, "message") || {}
            [
              extract_content_with_reasoning(message),
              parse_tool_calls(message["tool_calls"]),
              extract_openai_usage(resp)
            ]
          end
        end

        private

        # Extract content, handling LM Studio's separated reasoning_content block.
        # For reasoning models, LM Studio returns thinking in reasoning_content field.
        # We preserve just the actual content, not the chain-of-thought reasoning.
        def extract_content_with_reasoning(message)
          content = message["content"] || ""
          # LM Studio puts reasoning in separate field - we just use the content
          # The reasoning_content is the model's internal thinking, not the answer
          return content unless content.empty? && message["reasoning_content"]

          # Fallback: if content is empty but reasoning exists, something's wrong
          # Log it but return empty - tool calls may be the actual response
          content
        end

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
