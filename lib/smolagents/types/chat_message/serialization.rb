module Smolagents
  module Types
    module ChatMessageComponents
      # Serialization methods for ChatMessage.
      #
      # Provides hash conversion for API serialization and pattern matching support.
      module Serialization
        # Converts the message to a hash for serialization.
        #
        # Includes role and content, plus any optional fields (tool calls,
        # images, reasoning, tokens) that are present and non-empty.
        #
        # @return [Hash] Message as a hash with role, content, and optional fields
        def to_h
          {
            role:,
            content:,
            tool_calls: serialize_tool_calls,
            token_usage: token_usage&.to_h,
            images: presence(images),
            reasoning_content: presence(reasoning_content)
          }.compact
        end

        # Enables pattern matching with `in ChatMessage[role:, content:]`.
        #
        # Returns raw fields (not serialized) to preserve ToolCall objects
        # for pattern matching. Use `to_h` for API serialization.
        #
        # @param keys [Array, nil] Keys to extract (ignored, returns all)
        # @return [Hash] All fields as a hash with raw values
        def deconstruct_keys(_keys)
          { role:, content:, tool_calls:, raw:, token_usage:, images:, reasoning_content: }
        end

        private

        def serialize_tool_calls
          tool_calls&.any? ? tool_calls.map(&:to_h) : nil
        end

        def presence(collection)
          collection&.any? ? collection : nil
        end
      end
    end
  end
end
