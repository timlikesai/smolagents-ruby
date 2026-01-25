module Smolagents
  module Models
    module ModelSupport
      # Shared multipart content building for messages with images.
      #
      # Provides a common pattern for combining text and image content.
      # Each model adapter implements provider-specific image formatting.
      #
      # @example Include in a message formatter
      #   include ModelSupport::ImageContent
      #
      #   def image_block(image)
      #     # Provider-specific: OpenAI vs Anthropic format
      #   end
      module ImageContent
        # Builds multipart content array from message with images.
        #
        # Creates a text block followed by image blocks for each attached image.
        # Delegates to the provider-specific `image_block` method for formatting.
        #
        # @param msg [ChatMessage] Message with images attached
        # @return [Array<Hash>] Array of content blocks suitable for API
        # @example OpenAI format output
        #   [{ type: "text", text: "..." }, { type: "image_url", image_url: {...} }]
        # @example Anthropic format output
        #   [{ type: "text", text: "..." }, { type: "image", source: {...} }]
        def build_content_with_images(msg)
          text_block = { type: "text", text: msg.content || "" }
          image_blocks = msg.images.map { |img| image_block(img) }
          [text_block] + image_blocks
        end
      end
    end
  end
end
