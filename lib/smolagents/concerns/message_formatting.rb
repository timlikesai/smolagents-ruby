require "json"

module Smolagents
  module Concerns
    # Message and tool formatting for API compatibility
    #
    # Converts Smolagents ChatMessage and Tool objects to formats
    # expected by various LLM APIs (OpenAI-compatible, Anthropic, etc.)
    #
    # @example Converting messages for API
    #   messages = [
    #     ChatMessage.system("You are helpful"),
    #     ChatMessage.user("What is 2+2?")
    #   ]
    #   formatted = format_messages_for_api(messages)
    #   # => [{ role: "system", content: "..." }, { role: "user", content: "..." }]
    #
    # @see Model#generate For model implementations using this
    module MessageFormatting
      # Format all messages for API submission
      #
      # @param messages [Array<ChatMessage>] Messages to format
      # @return [Array<Hash>] API-compatible message hashes
      def format_messages_for_api(messages) = messages.map { |msg| format_single_message(msg) }

      # Format a single message for API
      #
      # Handles messages with or without tool calls.
      # Preserves tool_calls array if present.
      #
      # @param message [ChatMessage, Hash] Message to format
      # @return [Hash] API-compatible message hash
      def format_single_message(message)
        case message
        in ChatMessage[role:, content:, tool_calls: nil] then { role: role.to_s, content: content }
        in ChatMessage[role:, content:, tool_calls: Array => calls] then { role: role.to_s, content: content, tool_calls: format_tool_calls(calls) }
        else { role: message.role.to_s, content: message.content }
        end
      end

      # Parse an API response (subclass hook)
      #
      # @param response [Object] Raw API response
      # @return [ChatMessage] Parsed message
      # @raise [NotImplementedError] If not implemented by subclass
      def parse_api_response(_response) = raise(NotImplementedError, "#{self.class}#parse_api_response must be implemented")

      # Format tool calls for API submission
      #
      # Converts Smolagents ToolCall objects to OpenAI-compatible format.
      #
      # @param tool_calls [Array<ToolCall>] Tool calls from model
      # @return [Array<Hash>] API-compatible tool call hashes
      def format_tool_calls(tool_calls)
        tool_calls.map { |tc| { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json } } }
      end

      # Format all tools for API tool definitions
      #
      # @param tools [Array<Tool>] Tools to format
      # @return [Array<Hash>] API-compatible tool definition hashes
      def format_tools_for_api(tools)
        tools.map { |tool| format_tool_for_api(tool) }
      end

      # Format a single tool for API tool definitions
      #
      # Creates OpenAI-compatible function definition with JSON schema.
      #
      # @param tool [Tool] Tool to format
      # @return [Hash] API-compatible tool definition hash
      def format_tool_for_api(tool)
        { type: "function", function: { name: tool.name, description: tool.description, parameters: { type: "object", properties: tool.inputs, required: required_inputs(tool) } } }
      end

      # Get required input fields for a tool
      #
      # Filters out optional (nullable) inputs.
      #
      # @param tool [Tool] Tool to inspect
      # @return [Array<String>] Required field names
      def required_inputs(tool)
        tool.inputs.reject { |_, spec| spec[:nullable] }.keys
      end
    end
  end
end
