require "base64"

module Smolagents
  module Models
    module Anthropic
      # Message formatting for Anthropic API.
      #
      # Handles conversion of ChatMessage objects to Anthropic's
      # message format, including vision/image support.
      module MessageFormatter
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
        # Converts ChatMessage objects to Anthropic format, handling image content.
        #
        # @param messages [Array<ChatMessage>] Messages to format
        # @return [Array<Hash>] API-compatible messages with role and content
        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg.role.to_sym == :assistant ? "assistant" : "user",
              content: msg.images? ? build_content_with_images(msg) : (msg.content || "")
            }
          end
        end

        private

        def build_content_with_images(msg)
          [{ type: "text", text: msg.content || "" }] +
            msg.images.map { |img| image_block(img) }
        end

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
