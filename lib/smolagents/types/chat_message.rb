require "base64"

module Smolagents
  module Types
    # @return [Hash{String => String}] File extension to MIME type mapping for images
    IMAGE_MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

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
      class << self
        # Creates a system message.
        # @param content [String] The system prompt content
        # @return [ChatMessage] System role message
        def system(content) = create(MessageRole::SYSTEM, content: content)

        # Creates a user message.
        # @param content [String] The user's message content
        # @param images [Array<String>, nil] Image paths or URLs to attach
        # @return [ChatMessage] User role message
        def user(content, images: nil) = create(MessageRole::USER, content: content, images: images)

        # Creates an assistant message.
        # @param content [String, nil] The assistant's response content
        # @param tool_calls [Array<ToolCall>, nil] Tool calls made by the assistant
        # @param raw [Hash, nil] Raw API response for debugging
        # @param token_usage [TokenUsage, nil] Token usage for this response
        # @param reasoning_content [String, nil] Chain-of-thought reasoning (o1, DeepSeek)
        # @return [ChatMessage] Assistant role message
        def assistant(content, tool_calls: nil, raw: nil, token_usage: nil, reasoning_content: nil)
          create(MessageRole::ASSISTANT, content: content, tool_calls: tool_calls, raw: raw, token_usage: token_usage, reasoning_content: reasoning_content)
        end

        # Creates a tool call message.
        # @param tool_calls [Array<ToolCall>] The tool calls to make
        # @return [ChatMessage] Tool call role message
        def tool_call(tool_calls) = create(MessageRole::TOOL_CALL, tool_calls: tool_calls)

        # Creates a tool response message.
        # @param content [String] The tool execution result
        # @param tool_call_id [String, nil] ID linking response to call
        # @return [ChatMessage] Tool response role message
        def tool_response(content, tool_call_id: nil) = create(MessageRole::TOOL_RESPONSE, content: content, raw: { tool_call_id: tool_call_id })

        # Converts an image path/URL to a content block for multimodal APIs.
        # @param image [String] Image path or URL
        # @return [Hash] Content block suitable for API requests
        def image_to_content_block(image)
          if image.start_with?("http://", "https://")
            { type: "image_url", image_url: { url: image } }
          else
            data = Base64.strict_encode64(File.binread(image))
            mime = IMAGE_MIME_TYPES[File.extname(image).downcase] || "image/png"
            { type: "image_url", image_url: { url: "data:#{mime};base64,#{data}" } }
          end
        end

        private

        def create(role, content: nil, tool_calls: nil, raw: nil, token_usage: nil, images: nil, reasoning_content: nil)
          new(role: role, content: content, tool_calls: tool_calls, raw: raw, token_usage: token_usage, images: images, reasoning_content: reasoning_content)
        end
      end

      # Converts the message to a hash for serialization.
      # @return [Hash] Message as a hash with role, content, and optional fields
      def to_h
        { role: role, content: content }.tap do |hash|
          hash[:tool_calls] = tool_calls.map(&:to_h) if tool_calls&.any?
          hash[:token_usage] = token_usage.to_h if token_usage
          hash[:images] = images if images&.any?
          hash[:reasoning_content] = reasoning_content if reasoning_content && !reasoning_content.empty?
        end.compact
      end

      # Checks if this message contains tool calls.
      # @return [Boolean] True if tool_calls array has any elements
      def tool_calls? = tool_calls&.any? || false

      # Checks if this message has attached images.
      # @return [Boolean] True if images array has any elements
      def images? = images&.any? || false
    end
  end
end
