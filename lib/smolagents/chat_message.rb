# frozen_string_literal: true

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
  ChatMessage = Data.define(:role, :content, :tool_calls, :raw, :token_usage) do
    # Create a system message.
    # @param content [String] the system prompt
    # @return [ChatMessage]
    def self.system(content)
      new(
        role: MessageRole::SYSTEM,
        content: content,
        tool_calls: nil,
        raw: nil,
        token_usage: nil
      )
    end

    # Create a user message.
    # @param content [String] the user input
    # @return [ChatMessage]
    def self.user(content)
      new(
        role: MessageRole::USER,
        content: content,
        tool_calls: nil,
        raw: nil,
        token_usage: nil
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
        token_usage: token_usage
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
        token_usage: nil
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
        token_usage: nil
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
      result.compact
    end

    # Check if this message has tool calls.
    # @return [Boolean]
    def tool_calls?
      !tool_calls.nil? && tool_calls.any?
    end
  end
end
