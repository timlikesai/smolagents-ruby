require "base64"

module Smolagents
  module Types
    # MIME type mappings for image encoding
    IMAGE_MIME_TYPES = {
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".gif" => "image/gif",
      ".webp" => "image/webp"
    }.freeze

    module ChatMessageComponents
      # Image handling for multimodal chat messages.
      #
      # Provides encoding of local files and remote URLs into content blocks
      # suitable for multimodal LLM APIs.
      module ImageSupport
        # Converts an image path/URL to a content block for multimodal APIs.
        #
        # Supports both local files (encoded as base64 data URIs) and remote
        # URLs. Used internally when building messages for multimodal models.
        #
        # @param image [String] Local file path or HTTPS URL to image
        # @return [Hash] Content block with format { type: "image_url", image_url: {...} }
        # @raise [StandardError] If local file cannot be read
        def image_to_content_block(image)
          return url_content_block(image) if remote_url?(image)

          base64_content_block(image)
        end

        private

        def remote_url?(image) = image.start_with?("http://", "https://")

        def url_content_block(url)
          { type: "image_url", image_url: { url: } }
        end

        def base64_content_block(path)
          data = Base64.strict_encode64(File.binread(path))
          mime = IMAGE_MIME_TYPES[File.extname(path).downcase] || "image/png"
          { type: "image_url", image_url: { url: "data:#{mime};base64,#{data}" } }
        end
      end
    end
  end
end
