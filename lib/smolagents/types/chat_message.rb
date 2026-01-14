require "base64"

module Smolagents
  module Types
    # @return [Hash{String => String}] File extension to MIME type mapping for image serialization
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
        #
        # System messages define the agent's role, capabilities, and behavioral
        # constraints. They appear first in the conversation and influence all
        # subsequent responses.
        #
        # @param content [String] The system prompt content describing agent behavior
        # @return [ChatMessage] System role message
        # @example
        #   ChatMessage.system("You are a helpful Ruby coding assistant...")
        # @see SystemPromptStep For step representation
        def system(content) = create(MessageRole::SYSTEM, content:)

        # Creates a user message.
        #
        # User messages represent requests from humans. They can include text
        # and images for multimodal tasks.
        #
        # @param content [String] The user's message content
        # @param images [Array<String>, nil] Image paths or URLs to attach to message
        # @return [ChatMessage] User role message
        # @example
        #   ChatMessage.user("What is Ruby 4.0?")
        #   ChatMessage.user("Analyze this image", images: ["photo.jpg"])
        # @see TaskStep For user task representation
        def user(content, images: nil) = create(MessageRole::USER, content:, images:)

        # Creates an assistant message.
        #
        # Assistant messages represent the LLM's responses, including optional
        # tool calls and extended reasoning (for models like o1).
        #
        # @param content [String, nil] The assistant's response text
        # @param tool_calls [Array<ToolCall>, nil] Tool calls made by the assistant
        # @param raw [Hash, nil] Raw API response for debugging and event handling
        # @param token_usage [TokenUsage, nil] Input and output token counts
        # @param reasoning_content [String, nil] Extended thinking from o1, DeepSeek models
        # @return [ChatMessage] Assistant role message
        # @example
        #   ChatMessage.assistant("Let me search for that", tool_calls: [search_call])
        #   ChatMessage.assistant("The answer is...", reasoning_content: "Let me think...")
        # @see ToolCall For tool invocation format
        def assistant(content, tool_calls: nil, raw: nil, token_usage: nil, reasoning_content: nil)
          create(MessageRole::ASSISTANT, content:, tool_calls:, raw:, token_usage:, reasoning_content:)
        end

        # Creates a tool call message.
        #
        # Tool call messages represent a set of tools the assistant wants to invoke.
        # Used in tool-calling agent architectures (as opposed to code agents).
        #
        # @param tool_calls [Array<ToolCall>] The tool calls to make
        # @return [ChatMessage] Tool call role message
        # @example
        #   ChatMessage.tool_call([ToolCall.new(id: "1", name: "search", arguments: {q: "ruby"})])
        # @see ToolCall For tool invocation structure
        def tool_call(tool_calls) = create(MessageRole::TOOL_CALL, tool_calls:)

        # Creates a tool response message.
        #
        # Tool response messages return the results of tool execution back to the
        # assistant. They close the tool call-response loop in multi-turn conversations.
        #
        # @param content [String] The tool execution result or error message
        # @param tool_call_id [String, nil] ID linking response to the originating call
        # @return [ChatMessage] Tool response role message
        # @example
        #   ChatMessage.tool_response("Found 10 results for 'ruby'", tool_call_id: "1")
        #   ChatMessage.tool_response("Error: Tool not found")
        # @see ToolCall.id For linking calls to responses
        def tool_response(content, tool_call_id: nil) = create(MessageRole::TOOL_RESPONSE, content:, raw: { tool_call_id: })

        # Converts an image path/URL to a content block for multimodal APIs.
        #
        # Supports both local files (encoded as base64 data URIs) and remote
        # URLs. Used internally when building messages for multimodal models.
        #
        # @param image [String] Local file path or HTTPS URL to image
        # @return [Hash] Content block with format { type: "image_url", image_url: {...} }
        # @raise [StandardError] If local file cannot be read
        # @example
        #   block = ChatMessage.image_to_content_block("photo.jpg")
        #   # => { type: "image_url", image_url: { url: "data:image/jpeg;base64,..." } }
        #
        #   block = ChatMessage.image_to_content_block("https://example.com/image.png")
        #   # => { type: "image_url", image_url: { url: "https://..." } }
        # @see AgentImage For managed image handling
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
          new(role:, content:, tool_calls:, raw:, token_usage:, images:, reasoning_content:)
        end
      end

      # Converts the message to a hash for serialization.
      #
      # Includes role and content, plus any optional fields (tool calls,
      # images, reasoning, tokens) that are present and non-empty.
      #
      # @return [Hash] Message as a hash with role, content, and optional fields
      # @example
      #   ChatMessage.user("Hello").to_h
      #   # => { role: :user, content: "Hello" }
      #
      #   ChatMessage.assistant("Found results", tool_calls: [...]).to_h
      #   # => { role: :assistant, content: "Found results", tool_calls: [...] }
      def to_h
        { role:, content: }.tap do |hash|
          hash[:tool_calls] = tool_calls.map(&:to_h) if tool_calls&.any?
          hash[:token_usage] = token_usage.to_h if token_usage
          hash[:images] = images if images&.any?
          hash[:reasoning_content] = reasoning_content if reasoning_content && !reasoning_content.empty?
        end.compact
      end

      # Checks if this message contains tool calls.
      #
      # @return [Boolean] True if tool_calls array has any elements
      # @example
      #   msg.tool_calls?  # => true if message contains tool calls
      def tool_calls? = tool_calls&.any? || false

      # Checks if this message has attached images.
      #
      # @return [Boolean] True if images array has any elements
      # @example
      #   msg.images?  # => true if message includes image attachments
      def images? = images&.any? || false
    end
  end
end
