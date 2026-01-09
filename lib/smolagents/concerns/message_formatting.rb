# frozen_string_literal: true

require "json"

module Smolagents
  module Concerns
    # Shared message formatting utilities for model classes.
    # Provides consistent message conversion between our ChatMessage format
    # and various LLM provider formats.
    #
    # @example Using in a model class
    #   class MyModel < Model
    #     include Concerns::MessageFormatting
    #
    #     def generate(messages, **kwargs)
    #       formatted = format_messages_for_api(messages)
    #       # ... send to API
    #     end
    #   end
    module MessageFormatting
      # Format an array of ChatMessage objects for API consumption.
      # Override this in subclasses for provider-specific formatting.
      #
      # @param messages [Array<ChatMessage>] our internal message format
      # @return [Array<Hash>] provider-specific format
      def format_messages_for_api(messages)
        messages.map { |msg| format_single_message(msg) }
      end

      # Format a single ChatMessage.
      # Uses pattern matching for clean handling of different message types.
      #
      # @param message [ChatMessage] message to format
      # @return [Hash] formatted message
      def format_single_message(message)
        case message
        in ChatMessage[role:, content:, tool_calls: nil]
          { role: role.to_s, content: content }
        in ChatMessage[role:, content:, tool_calls: Array => calls]
          {
            role: role.to_s,
            content: content,
            tool_calls: format_tool_calls(calls)
          }
        else
          { role: message.role.to_s, content: message.content }
        end
      end

      # Parse API response into our ChatMessage format.
      # Override this in subclasses for provider-specific parsing.
      #
      # @param response [Hash] API response
      # @return [ChatMessage] our internal format
      def parse_api_response(response)
        raise NotImplementedError, "#{self.class}#parse_api_response must be implemented"
      end

      # Format tool calls for API (override per provider).
      #
      # @param tool_calls [Array<ToolCall>] our tool call format
      # @return [Array<Hash>] provider-specific format
      def format_tool_calls(tool_calls)
        tool_calls.map do |tc|
          {
            id: tc.id,
            type: "function",
            function: {
              name: tc.name,
              arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json
            }
          }
        end
      end

      # Format tools/functions for API (override per provider).
      #
      # @param tools [Array<Tool>] available tools
      # @return [Array<Hash>] provider-specific format
      def format_tools_for_api(tools)
        tools.map do |tool|
          {
            type: "function",
            function: {
              name: tool.name,
              description: tool.description,
              parameters: {
                type: "object",
                properties: tool.inputs,
                required: tool.inputs.reject { |_, spec| spec["nullable"] }.keys
              }
            }
          }
        end
      end
    end
  end
end
