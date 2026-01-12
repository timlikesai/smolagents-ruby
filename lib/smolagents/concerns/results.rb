module Smolagents
  module Concerns
    module Results
      def map_results(results, **fields)
        Array(results).map do |result|
          fields.transform_values { |spec| extract_field(result, spec) }
        end
      end

      def extract_and_map(data, path:, **fields)
        results = data.dig(*path) || []
        map_results(results, **fields)
      end

      def format_results(results, title: :title, link: :link, description: :description, indexed: false, header: "## Search Results")
        return "No results found." if Array(results).empty?

        formatted = results.map.with_index(1) do |result, idx|
          title_val = result[title] || result[title.to_s]
          link_val = result[link] || result[link.to_s]
          desc_val = result[description] || result[description.to_s]

          line = indexed ? "#{idx}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
          desc_str = desc_val.to_s.strip
          desc_str.empty? ? line : "#{line}\n#{desc_val}"
        end

        "#{header}\n\n#{formatted.join("\n\n")}"
      end

      def format_results_with_metadata(results, title: "title", link: "link", snippet: "snippet", date: "date")
        return "No results found." if Array(results).empty?

        formatted = results.map.with_index do |result, idx|
          parts = ["#{idx}. [#{result[title]}](#{result[link]})"]
          parts << "Date: #{result[date]}" if result[date]
          parts << result[snippet] if result[snippet]
          parts.join("\n")
        end

        "## Search Results\n#{formatted.join("\n\n")}"
      end

      private

      def extract_field(result, spec)
        case spec
        when Proc then spec.call(result)
        when Array then result.dig(*spec)
        when Symbol then result[spec] || result[spec.to_s]
        else result[spec] || result[spec.to_sym]
        end
      end
    end
  end
end
