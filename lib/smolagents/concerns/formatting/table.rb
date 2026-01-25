module Smolagents
  module Concerns
    # Table formatting for data display.
    #
    # Provides ASCII table rendering for arrays of hashes. Includes column
    # width calculation, truncation, and separator formatting.
    #
    # @example Format data as table
    #   as_table(max_width: 50)
    #   # => "| Header1 | Header2 |\n|---------|----------|\n| val1 | val2 |"
    #
    # @see ResultFormatting For other output formats
    module TableFormatting
      # Format data as ASCII table
      #
      # Only works with arrays of hashes. Falls back to to_s for other types.
      #
      # @param max_width [Integer] Maximum column width (default: 30)
      # @return [String] ASCII table
      def as_table(max_width: 30)
        return data.to_s unless data.is_a?(Array) && data.first.is_a?(Hash)

        headers = data.first.keys
        widths = calculate_column_widths(headers, max_width)
        [format_header_row(headers, widths), format_separator_row(widths),
         *format_data_rows(headers, widths)].join("\n")
      end

      private

      # Calculate column widths for table formatting
      # @api private
      def calculate_column_widths(headers, max_width)
        headers.map { |hdr| [hdr.to_s.length, max_column_value_length(hdr)].max.clamp(1, max_width) }
      end

      # Get maximum value length for a column
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

      # Truncate string with ellipsis if needed
      # @api private
      def truncate_str(str, width) = str.length > width ? "#{str[0...(width - 3)]}..." : str
    end
  end
end
