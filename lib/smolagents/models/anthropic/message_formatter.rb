require "base64"
require_relative "../support"

module Smolagents
  module Models
    module Anthropic
      # Message formatting for Anthropic API.
      #
      # Handles conversion of ChatMessage objects to Anthropic's
      # message format, including vision/image support.
      # Includes sanitization to ensure valid role alternation.
      module MessageFormatter
        include ModelSupport::ImageContent
        include Concerns::MessageSanitization

        # MIME type mapping for image files
        MIME_TYPES = {
          ".jpg" => "image/jpeg",
          ".jpeg" => "image/jpeg",
          ".png" => "image/png",
          ".gif" => "image/gif",
          ".webp" => "image/webp"
        }.freeze

        # Formats messages for Anthropic API.
        #
        # Sanitizes message sequence to ensure valid role alternation,
        # then converts ChatMessage objects to Anthropic format.
        #
        # @param messages [Array<ChatMessage>] Messages to format
        # @return [Array<Hash>] API-compatible messages with role and content
        def format_messages(messages)
          sanitized = sanitize_message_roles(messages)
          sanitized.map do |msg|
            {
              role: msg.role.to_sym == :assistant ? "assistant" : "user",
              content: msg.images? ? build_content_with_images(msg) : (msg.content || "")
            }
          end
        end

        private

        # Converts image to Anthropic content block format.
        #
        # Handles both URL-based and local file images with appropriate encoding.
        #
        # @param image [String] Image path or URL
        # @return [Hash] Anthropic image content block
        def image_block(image)
          image.start_with?("http://", "https://") ? url_image_block(image) : base64_image_block(image)
        end

        def url_image_block(url) = { type: "image", source: { type: "url", url: } }

        def base64_image_block(path)
          { type: "image", source: { type: "base64", media_type: mime_type_for(path),
                                     data: Base64.strict_encode64(File.binread(path)) } }
        end

        def mime_type_for(path)
          MIME_TYPES[File.extname(path).downcase] || "image/png"
        end
      end
    end
  end
end
