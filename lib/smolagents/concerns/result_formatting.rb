module Smolagents
  module Concerns
    module ResultFormatting
      def as_markdown(max_items: nil)
        items = max_items && data.is_a?(Array) ? data.take(max_items) : data
        case items
        when Array then format_array_markdown(items)
        when Hash then items.map { |key, val| "**#{key}:** #{val.is_a?(Array) ? val.join(", ") : val}" }.join("\n")
        when nil then ""
        else items.to_s
        end
      end

      def format_array_markdown(items)
        return "*(empty)*" if items.empty?

        if items.first.is_a?(Hash)
          items.map.with_index(1) { |item, idx| "**#{idx}.** #{format_hash_inline(item)}" }.join("\n")
        else
          items.map { |item| "- #{item}" }.join("\n")
        end
      end

      def format_hash_inline(hash)
        hash.map { |key, val| "**#{key}:** #{val}" }.join(", ")
      end

      def as_table(max_width: 30)
        return data.to_s unless data.is_a?(Array) && data.first.is_a?(Hash)

        headers = data.first.keys
        widths = calculate_column_widths(headers, max_width)
        [format_header_row(headers, widths), format_separator_row(widths), *format_data_rows(headers, widths)].join("\n")
      end

      def calculate_column_widths(headers, max_width)
        headers.map { |hdr| [hdr.to_s.length, max_column_value_length(hdr)].max.clamp(1, max_width) }
      end

      def max_column_value_length(header)
        data.map { |row| row[header].to_s.length }.max || 0
      end

      def format_header_row(headers, widths)
        headers.zip(widths).map { |hdr, width| hdr.to_s.ljust(width) }.join(" | ")
      end

      def format_separator_row(widths)
        widths.map { |width| "-" * width }.join("-+-")
      end

      def format_data_rows(headers, widths)
        data.map { |row| format_table_row(row, headers, widths) }
      end

      def format_table_row(row, headers, widths)
        headers.zip(widths).map { |hdr, width| truncate_str(row[hdr].to_s, width).ljust(width) }.join(" | ")
      end

      def as_list(bullet: "-") = to_a.map { |item| "#{bullet} #{format_item(item)}" }.join("\n")
      def as_numbered_list = to_a.map.with_index(1) { |item, idx| "#{idx}. #{format_item(item)}" }.join("\n")

      def to_json(*)
        (require "json"
         data.to_json(*))
      end

      def as_yaml
        (require "yaml"
         data.to_yaml)
      end

      private

      def format_item(item) = item.is_a?(Hash) ? item.map { |key, val| "#{key}: #{val}" }.join(", ") : item.to_s
      def truncate_str(str, width) = str.length > width ? "#{str[0...(width - 3)]}..." : str
    end
  end
end
