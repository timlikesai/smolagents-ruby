module Smolagents
  module Models
    class Model
      # Tool call parsing for Model instances.
      #
      # Provides the default pass-through implementation for parsing tool calls
      # from model responses. Subclasses override to handle provider-specific formats.
      module ToolParsing
        # Parses tool calls from a model response.
        #
        # The default implementation returns the input as-is. Subclasses override
        # to handle provider-specific tool call formats:
        # - OpenAI: Array of { id, type, function: { name, arguments } }
        # - Anthropic: Array of { type: "tool_use", id, name, input }
        #
        # @param message [Object] The raw tool call data from the model response
        # @return [Object] Parsed tool calls in normalized format
        def parse_tool_calls(message) = message
      end
    end
  end
end
