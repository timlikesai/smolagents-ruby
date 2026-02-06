require_relative "../support"

module Smolagents
  module Models
    module OpenAI
      # Message formatting for OpenAI API.
      #
      # Converts ChatMessage objects to OpenAI-compatible format,
      # handling role mapping, images, and tool calls.
      module MessageFormatter
        include ModelSupport::ImageContent

        # Formats messages for OpenAI API.
        #
        # Converts ChatMessage objects to OpenAI-compatible format with proper role mapping.
        #
        # @param messages [Array<ChatMessage>] Messages to format
        # @return [Array<Hash>] API-compatible message hashes with role and content
        def format_messages(messages) = messages.map { |msg| format_message(msg) }

        private

        def format_message(msg)
          formatted = {
            role: map_role(msg.role, msg),
            content: msg.images? ? build_content_with_images(msg) : msg.content,
            tool_calls: format_message_tool_calls(msg.tool_calls)
          }
          formatted[:tool_call_id] = msg.raw[:tool_call_id] if native_tool_response?(msg)
          formatted.compact
        end

        # Maps internal roles to OpenAI API roles.
        # - tool_response with tool_call_id -> "tool" (native tool calling)
        # - tool_response without tool_call_id -> "user" (code mode observations)
        # - tool_call -> assistant (tool calls are assistant messages)
        def map_role(role, msg = nil)
          case role.to_sym
          when :tool_response then native_tool_response?(msg) ? "tool" : "user"
          when :tool_call then "assistant"
          else role.to_s
          end
        end

        def native_tool_response?(msg)
          msg&.raw.is_a?(Hash) && msg.raw[:tool_call_id]
        end

        # Converts image to OpenAI content block format.
        #
        # Delegates to ChatMessage.image_to_content_block for OpenAI-compatible format.
        #
        # @param image [String] Image path or URL
        # @return [Hash] OpenAI image_url content block
        def image_block(image) = Smolagents::ChatMessage.image_to_content_block(image)

        def format_message_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.map do |call|
            args = call.arguments.is_a?(String) ? call.arguments : call.arguments.to_json
            { id: call.id, type: "function", function: { name: call.name, arguments: args } }
          end
        end
      end
    end
  end
end
