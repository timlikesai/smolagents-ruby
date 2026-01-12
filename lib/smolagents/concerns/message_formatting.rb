require "json"

module Smolagents
  module Concerns
    module MessageFormatting
      def format_messages_for_api(messages) = messages.map { |msg| format_single_message(msg) }

      def format_single_message(message)
        case message
        in ChatMessage[role:, content:, tool_calls: nil] then { role: role.to_s, content: content }
        in ChatMessage[role:, content:, tool_calls: Array => calls] then { role: role.to_s, content: content, tool_calls: format_tool_calls(calls) }
        else { role: message.role.to_s, content: message.content }
        end
      end

      def parse_api_response(_response) = raise(NotImplementedError, "#{self.class}#parse_api_response must be implemented")

      def format_tool_calls(tool_calls)
        tool_calls.map { |tc| { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json } } }
      end

      def format_tools_for_api(tools)
        tools.map { |tool| format_tool_for_api(tool) }
      end

      def format_tool_for_api(tool)
        { type: "function", function: { name: tool.name, description: tool.description, parameters: { type: "object", properties: tool.inputs, required: required_inputs(tool) } } }
      end

      def required_inputs(tool)
        tool.inputs.reject { |_, spec| spec[:nullable] }.keys
      end
    end
  end
end
