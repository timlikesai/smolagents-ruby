require_relative "../support"

module Smolagents
  module Models
    module Anthropic
      # Request parameter building for Anthropic API.
      #
      # Handles construction of API request parameters including
      # system message extraction and tool formatting.
      module RequestBuilder
        include ModelSupport::RequestBuilding

        # Build parameters for non-streaming request
        def build_params(messages, stop_sequences, temperature, max_tokens, tools)
          system_content, user_messages = extract_system_message(messages)
          merge_params(
            build_base_params(messages: user_messages, temperature:, max_tokens:, tools:),
            { system: system_content, stop_sequences: }
          )
        end

        # Build parameters for streaming request
        def build_stream_params(messages)
          system_content, user_messages = extract_system_message(messages)
          merge_params(
            build_base_params(messages: user_messages, temperature: @temperature, max_tokens: @max_tokens),
            { stream: true, system: system_content }
          )
        end

        private

        # Anthropic requires system messages as separate parameter
        def extract_system_message(messages)
          system_msgs, user_msgs = messages.partition { |msg| msg.role.to_sym == :system }
          system_content = system_msgs.any? ? system_msgs.map(&:content).join("\n\n") : nil
          [system_content, user_msgs]
        end

        # Format tools for Anthropic's tool use format
        def format_tools(tools) = tools.map { |tool| format_single_tool(tool) }

        def format_single_tool(tool)
          {
            name: tool.name,
            description: tool.description,
            input_schema: {
              type: "object",
              properties: tool_properties(tool),
              required: tool_required_fields(tool)
            }
          }
        end
      end
    end
  end
end
