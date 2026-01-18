module Smolagents
  module Types
    # Immutable representation of a tool call from the LLM.
    #
    # Represents a single tool invocation with its name, arguments, and
    # unique ID for linking with tool responses. Used in tool-calling
    # agent architectures.
    #
    # @!attribute [r] name
    #   @return [String] Name of the tool to call
    # @!attribute [r] arguments
    #   @return [Hash] Arguments to pass to the tool
    # @!attribute [r] id
    #   @return [String] Unique identifier linking call to response
    #
    # @example Creating a tool call
    #   call = Smolagents::Types::ToolCall.new(
    #     name: "search",
    #     arguments: { query: "Ruby 4.0" },
    #     id: "call_123"
    #   )
    #   call.name  # => "search"
    #
    # @see ChatMessage#tool_calls For tool calls in messages
    # @see ToolOutput For tool execution results
    ToolCall = Data.define(:name, :arguments, :id) do
      include TypeSupport::Deconstructable

      # Converts tool call to hash in OpenAI function calling format.
      #
      # @return [Hash] Hash with :id, :type (always "function"), and :function (name and arguments)
      def to_h = { id:, type: "function", function: { name:, arguments: } }
    end
  end
end
