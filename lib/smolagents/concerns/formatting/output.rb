require "json"
require "yaml"
require_relative "table"

module Smolagents
  module Concerns
    # Result formatting utilities for various output formats.
    #
    # Provides methods to format data as markdown, tables, lists, JSON, YAML.
    # Designed to work with data objects that provide a `data` accessor.
    #
    # @example Formatting as markdown
    #   result.as_markdown  # => "- item1\n- item2"
    #
    # @example Formatting as list
    #   result.as_list(bullet: "*")  # => "* item1\n* item2"
    #
    # @see Results For result mapping
    # @see TableFormatting For table output
    module ResultFormatting
      include TableFormatting

      # Format data as markdown
      #
      # Handles arrays, hashes, and scalars appropriately for markdown.
      #
      # @param max_items [Integer, nil] Maximum items to include
      # @return [String] Markdown-formatted string
      def as_markdown(max_items: nil)
        items = max_items && data.is_a?(Array) ? data.take(max_items) : data
        case items
        in Array then format_array_markdown(items)
        in Hash then format_hash_markdown(items)
        in nil then ""
        else items.to_s
        end
      end

      def format_hash_markdown(hash)
        hash.map { |key, val| "**#{key}:** #{format_value(val)}" }.join("\n")
      end

      def format_value(val)
        val.is_a?(Array) ? val.join(", ") : val
      end

      # Format array as markdown bullet list or numbered list of objects
      # @api private
      def format_array_markdown(items)
        return "*(empty)*" if items.empty?

        if items.first.is_a?(Hash)
          items.map.with_index(1) { |item, idx| "**#{idx}.** #{format_hash_inline(item)}" }.join("\n")
        else
          items.map { |item| "- #{item}" }.join("\n")
        end
      end

      # Format hash as inline key-value pairs
      # @api private
      def format_hash_inline(hash)
        hash.map { |key, val| "**#{key}:** #{val}" }.join(", ")
      end

      # Format data as bullet list
      #
      # @param bullet [String] Bullet character (default: "-")
      # @return [String] Bullet list
      def as_list(bullet: "-") = to_a.map { |item| "#{bullet} #{format_item(item)}" }.join("\n")

      # Format data as numbered list
      #
      # @return [String] Numbered list
      def as_numbered_list = to_a.map.with_index(1) { |item, idx| "#{idx}. #{format_item(item)}" }.join("\n")

      # Convert data to JSON
      #
      # @return [String] JSON string
      def to_json(...) = data.to_json(...)

      # Convert data to YAML
      #
      # @return [String] YAML string
      def as_yaml = data.to_yaml

      private

      # Format a single item for list output
      # @api private
      def format_item(item) = item.is_a?(Hash) ? item.map { |key, val| "#{key}: #{val}" }.join(", ") : item.to_s
    end
  end
end
