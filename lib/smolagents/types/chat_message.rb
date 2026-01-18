require_relative "chat_message/image_support"
require_relative "chat_message/predicates"
require_relative "chat_message/serialization"
require_relative "chat_message/factories"

module Smolagents
  module Types
    # Immutable message in a conversation with an LLM.
    #
    # ChatMessage represents a single message in a chat conversation, supporting
    # various roles (system, user, assistant, tool_call, tool_response) and
    # optional attachments like images and tool calls.
    #
    # Use the factory methods (system, user, assistant, etc.) to create messages
    # rather than calling new directly.
    #
    # @example Creating messages
    #   system = Types::ChatMessage.system("You are a helpful assistant")
    #   user = Types::ChatMessage.user("What is 2+2?")
    #   assistant = Types::ChatMessage.assistant("The answer is 4")
    #
    # @example User message with images
    #   msg = Types::ChatMessage.user("What's in this image?", images: ["photo.jpg"])
    #
    # @example Assistant message with tool calls
    #   msg = Types::ChatMessage.assistant("Let me search for that",
    #     tool_calls: [Types::ToolCall.new(id: "1", name: "search", arguments: {q: "ruby"})])
    #
    # @example Converting to hash for serialization
    #   msg.to_h
    #   # => { role: :user, content: "Hello" }
    #
    # @see MessageRole For available role values
    # @see ToolCall For tool call structures
    ChatMessage = Data.define(:role, :content, :tool_calls, :raw, :token_usage, :images, :reasoning_content) do
      include ChatMessageComponents::Predicates
      include ChatMessageComponents::Serialization
      extend ChatMessageComponents::Factories
    end
  end
end
