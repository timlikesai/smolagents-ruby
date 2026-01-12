# frozen_string_literal: true

require "base64"

module Smolagents
  IMAGE_MIME_TYPES = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png", ".gif" => "image/gif", ".webp" => "image/webp" }.freeze

  ChatMessage = Data.define(:role, :content, :tool_calls, :raw, :token_usage, :images) do
    class << self
      def system(content) = create(MessageRole::SYSTEM, content: content)
      def user(content, images: nil) = create(MessageRole::USER, content: content, images: images)

      def assistant(content, tool_calls: nil, raw: nil,
                    token_usage: nil)
        create(MessageRole::ASSISTANT, content: content, tool_calls: tool_calls, raw: raw, token_usage: token_usage)
      end

      def tool_call(tool_calls) = create(MessageRole::TOOL_CALL, tool_calls: tool_calls)
      def tool_response(content, tool_call_id: nil) = create(MessageRole::TOOL_RESPONSE, content: content, raw: { tool_call_id: tool_call_id })

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

      def create(role, content: nil, tool_calls: nil, raw: nil, token_usage: nil, images: nil)
        new(role: role, content: content, tool_calls: tool_calls, raw: raw, token_usage: token_usage, images: images)
      end
    end

    def to_h
      { role: role, content: content }.tap do |h|
        h[:tool_calls] = tool_calls.map(&:to_h) if tool_calls&.any?
        h[:token_usage] = token_usage.to_h if token_usage
        h[:images] = images if images&.any?
      end.compact
    end

    def tool_calls? = tool_calls&.any? || false
    def images? = images&.any? || false
  end
end
