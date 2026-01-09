# frozen_string_literal: true

require "base64"

module Smolagents
  # Represents a chat message in a conversation.
  # @!attribute [r] role
  #   @return [Symbol] message role (see MessageRole)
  # @!attribute [r] content
  #   @return [String, Array<Hash>, nil] message content
  # @!attribute [r] tool_calls
  #   @return [Array<ToolCall>, nil] tool calls in this message
  # @!attribute [r] raw
  #   @return [Object, nil] raw API response
  # @!attribute [r] token_usage
  #   @return [TokenUsage, nil] token usage for this message
  # @!attribute [r] images
  #   @return [Array<String>, nil] image paths or URLs
  ChatMessage = Data.define(:role, :content, :tool_calls, :raw, :token_usage, :images) do
    # Create a system message.
    # @param content [String] the system prompt
    # @return [ChatMessage]
    def self.system(content)
      new(
        role: MessageRole::SYSTEM,
        content: content,
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: nil
      )
    end

    # Create a user message.
    # @param content [String] the user input
    # @param images [Array<String>, nil] image paths or URLs
    # @return [ChatMessage]
    def self.user(content, images: nil)
      new(
        role: MessageRole::USER,
        content: content,
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: images
      )
    end

    # Create an assistant message.
    # @param content [String] the assistant response
    # @param tool_calls [Array<ToolCall>, nil] tool calls to make
    # @param raw [Object, nil] raw API response
    # @param token_usage [TokenUsage, nil] token usage information
    # @return [ChatMessage]
    def self.assistant(content, tool_calls: nil, raw: nil, token_usage: nil)
      new(
        role: MessageRole::ASSISTANT,
        content: content,
        tool_calls: tool_calls,
        raw: raw,
        token_usage: token_usage,
        images: nil
      )
    end

    # Create a tool call message.
    # @param tool_calls [Array<ToolCall>] the tool calls
    # @return [ChatMessage]
    def self.tool_call(tool_calls)
      new(
        role: MessageRole::TOOL_CALL,
        content: nil,
        tool_calls: tool_calls,
        raw: nil,
        token_usage: nil,
        images: nil
      )
    end

    # Create a tool response message.
    # @param content [String] the tool result
    # @param tool_call_id [String] the ID of the tool call this responds to
    # @return [ChatMessage]
    def self.tool_response(content, tool_call_id: nil)
      new(
        role: MessageRole::TOOL_RESPONSE,
        content: content,
        tool_calls: nil,
        raw: { tool_call_id: tool_call_id },
        token_usage: nil,
        images: nil
      )
    end

    # Convert to hash representation suitable for API calls.
    # @return [Hash]
    def to_h
      result = {
        role: role,
        content: content
      }
      result[:tool_calls] = tool_calls.map(&:to_h) if tool_calls&.any?
      result[:token_usage] = token_usage.to_h if token_usage
      result[:images] = images if images&.any?
      result.compact
    end

    # Check if this message has tool calls.
    # @return [Boolean]
    def tool_calls?
      !tool_calls.nil? && tool_calls.any?
    end

    # Check if this message has images.
    # @return [Boolean]
    def images?
      !images.nil? && images.any?
    end

    # Convert an image path or URL to a data URI.
    # @param image [String] image path or URL
    # @return [Hash] image content block for API
    def self.image_to_content_block(image)
      if image.start_with?("http://", "https://")
        # URL - use directly
        {
          type: "image_url",
          image_url: { url: image }
        }
      else
        # File path - encode as base64
        data = File.binread(image)
        mime_type = detect_mime_type(image)
        base64_data = Base64.strict_encode64(data)
        {
          type: "image_url",
          image_url: {
            url: "data:#{mime_type};base64,#{base64_data}"
          }
        }
      end
    end

    # Detect MIME type from file extension.
    # @param path [String] file path
    # @return [String] MIME type
    def self.detect_mime_type(path)
      case File.extname(path).downcase
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png" then "image/png"
      when ".gif" then "image/gif"
      when ".webp" then "image/webp"
      else "image/png"
      end
    end
  end
end
