module Smolagents
  module Concerns
    # Output formatting methods for tool results.
    module ResultFormatting
      def as_markdown(max_items: nil)
        items = max_items && data.is_a?(Array) ? data.take(max_items) : data
        case items
        when Array then if items.empty?
                          "*(empty)*"
                        else
                          (if items.first.is_a?(Hash)
                             items.map.with_index(1) do |item, i|
                               "**#{i}.** " + item.map { |k, v|
                                 "**#{k}:** #{v}"
                               }.join(", ")
                             end.join("\n")
                           else
                             items.map do |item|
                               "- #{item}"
                             end.join("\n")
                           end)
                        end
        when Hash then items.map { |k, v| "**#{k}:** #{v.is_a?(Array) ? v.join(", ") : v}" }.join("\n")
        when nil then ""
        else items.to_s
        end
      end

      def as_table(max_width: 30)
        return data.to_s unless data.is_a?(Array) && data.first.is_a?(Hash)

        headers = data.first.keys
        widths = headers.map { |h| [h.to_s.length, data.map { |row| row[h].to_s.length }.max || 0].max.clamp(1, max_width) }
        [headers.zip(widths).map { |h, w| h.to_s.ljust(w) }.join(" | "), widths.map { |w| "-" * w }.join("-+-"),
         *data.map { |row| headers.zip(widths).map { |h, w| truncate_str(row[h].to_s, w).ljust(w) }.join(" | ") }].join("\n")
      end

      def as_list(bullet: "-") = to_a.map { |item| "#{bullet} #{format_item(item)}" }.join("\n")
      def as_numbered_list = to_a.map.with_index(1) { |item, i| "#{i}. #{format_item(item)}" }.join("\n")

      def to_json(*)
        (require "json"
         data.to_json(*))
      end

      def as_yaml
        (require "yaml"
         data.to_yaml)
      end

      private

      def format_item(item) = item.is_a?(Hash) ? item.map { |k, v| "#{k}: #{v}" }.join(", ") : item.to_s
      def truncate_str(str, width) = str.length > width ? "#{str[0...(width - 3)]}..." : str
    end
  end
end
