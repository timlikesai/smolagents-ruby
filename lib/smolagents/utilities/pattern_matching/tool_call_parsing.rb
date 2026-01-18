require "json"

module Smolagents
  module Utilities
    module PatternMatching
      # Parses tool calls from XML and JSON formats.
      # Handles <tool_call>, tool_request markdown, and converts to Ruby code.
      module ToolCallParsing
        # XML format: <tool_call>{"name": "x", "arguments": {...}}</tool_call>
        TOOL_CALL_XML = %r{<tool_call>\s*(\{.+?\})\s*</tool_call>}mi

        # Markdown format: ```tool_request\n{...}\n```
        TOOL_REQUEST_MD = /```tool_request\s*\n(\{.+?\})\s*\n```/mi

        class << self
          def extract_tool_call_xml(text)
            extract_tool_json(text, TOOL_CALL_XML)
          end

          def extract_tool_request(text)
            extract_tool_json(text, TOOL_REQUEST_MD)
          end

          def extract_tool_json(text, pattern)
            match = text.match(pattern)
            return nil unless match

            data = JSON.parse(match[1])
            tool_call_to_ruby(data["name"], data["arguments"])
          rescue JSON::ParserError
            nil
          end

          def tool_call_to_ruby(name, args)
            return nil unless name && args

            formatted_args = args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
            "result = #{name}(#{formatted_args})"
          end
        end
      end
    end
  end
end
