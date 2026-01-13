require "json"
require "yaml"

module Smolagents
  module Concerns
    # Result formatting utilities for various output formats
    #
    # Provides methods to format data as markdown, tables, lists, JSON, YAML, etc.
    # Designed to work with data objects that provide a `data` accessor.
    #
    # @example Formatting as markdown
    #   result.as_markdown  # => "- item1\n- item2"
    #
    # @example Formatting as table
    #   result.as_table(max_width: 50)
    #   # => "| Header1 | Header2 |\n|---------|----------|\n| val1 | val2 |"
    #
    # @example Formatting as list
    #   result.as_list(bullet: "*")  # => "* item1\n* item2"
    #
    # @see Results For result mapping
    module ResultFormatting
      # Format data as markdown
      #
      # Handles arrays, hashes, and scalars appropriately for markdown.
      #
      # @param max_items [Integer, nil] Maximum items to include
      # @return [String] Markdown-formatted string
      # @example
      #   as_markdown(max_items: 5)
      def as_markdown(max_items: nil)
        items = max_items && data.is_a?(Array) ? data.take(max_items) : data
        case items
        when Array then format_array_markdown(items)
        when Hash then items.map { |key, val| "**#{key}:** #{val.is_a?(Array) ? val.join(", ") : val}" }.join("\n")
        when nil then ""
        else items.to_s
        end
      end

      # Format array as markdown bullet list or numbered list of objects
      # @param items [Array] Items to format
      # @return [String] Markdown list
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
      # @param hash [Hash] Hash to format
      # @return [String] Inline format
      # @api private
      def format_hash_inline(hash)
        hash.map { |key, val| "**#{key}:** #{val}" }.join(", ")
      end

      # Format data as ASCII table
      #
      # Only works with arrays of hashes. Falls back to to_s for other types.
      #
      # @param max_width [Integer] Maximum column width (default: 30)
      # @return [String] ASCII table
      # @example
      #   as_table(max_width: 50)
      def as_table(max_width: 30)
        return data.to_s unless data.is_a?(Array) && data.first.is_a?(Hash)

        headers = data.first.keys
        widths = calculate_column_widths(headers, max_width)
        [format_header_row(headers, widths), format_separator_row(widths), *format_data_rows(headers, widths)].join("\n")
      end

      # Calculate column widths for table formatting
      # @param headers [Array] Column headers
      # @param max_width [Integer] Maximum width per column
      # @return [Array<Integer>] Width for each column
      # @api private
      def calculate_column_widths(headers, max_width)
        headers.map { |hdr| [hdr.to_s.length, max_column_value_length(hdr)].max.clamp(1, max_width) }
      end

      # Get maximum value length for a column
      # @param header [String] Column header
      # @return [Integer] Maximum value length
      # @api private
      def max_column_value_length(header)
        data.map { |row| row[header].to_s.length }.max || 0
      end

      # Format table header row
      # @api private
      def format_header_row(headers, widths)
        headers.zip(widths).map { |hdr, width| hdr.to_s.ljust(width) }.join(" | ")
      end

      # Format table separator row
      # @api private
      def format_separator_row(widths)
        widths.map { |width| "-" * width }.join("-+-")
      end

      # Format all table data rows
      # @api private
      def format_data_rows(headers, widths)
        data.map { |row| format_table_row(row, headers, widths) }
      end

      # Format single table row
      # @api private
      def format_table_row(row, headers, widths)
        headers.zip(widths).map { |hdr, width| truncate_str(row[hdr].to_s, width).ljust(width) }.join(" | ")
      end

      # Format data as bullet list
      #
      # @param bullet [String] Bullet character (default: "-")
      # @return [String] Bullet list
      # @example
      #   as_list(bullet: "*")  # => "* item1\n* item2"
      def as_list(bullet: "-") = to_a.map { |item| "#{bullet} #{format_item(item)}" }.join("\n")

      # Format data as numbered list
      #
      # @return [String] Numbered list
      # @example
      #   as_numbered_list  # => "1. item1\n2. item2"
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

      # Truncate string with ellipsis if needed
      # @api private
      def truncate_str(str, width) = str.length > width ? "#{str[0...(width - 3)]}..." : str
    end
  end
end
