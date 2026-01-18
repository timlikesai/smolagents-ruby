require_relative "../support"

module Smolagents
  module Models
    module Anthropic
      # Response parsing for Anthropic API.
      #
      # Handles parsing of API responses including text content,
      # tool calls, and token usage extraction.
      module ResponseParser
        include ModelSupport::ResponseParsing

        # Parse API response into ChatMessage
        def parse_response(response)
          parse_chat_response(response, provider: "Anthropic") do |resp|
            blocks = resp["content"] || []
            [
              extract_text_content(blocks),
              extract_tool_calls(blocks),
              extract_anthropic_usage(resp)
            ]
          end
        end

        private

        def extract_text_content(blocks)
          blocks.filter_map { it["text"] if it["type"] == "text" }.join("\n")
        end

        def extract_tool_calls(blocks)
          calls = blocks.filter_map do |block|
            next unless block["type"] == "tool_use"

            Smolagents::ToolCall.new(
              id: block["id"],
              name: block["name"],
              arguments: block["input"] || {}
            )
          end
          calls.any? ? calls : nil
        end

        def extract_anthropic_usage(response)
          parse_token_usage(response["usage"], input_key: "input_tokens", output_key: "output_tokens")
        end
      end
    end
  end
end
