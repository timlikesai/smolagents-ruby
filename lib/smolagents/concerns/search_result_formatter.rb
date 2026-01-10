# frozen_string_literal: true

module Smolagents
  module Concerns
    # Shared formatting for search result tools.
    module SearchResultFormatter
      def format_search_results(results, title: :title, link: :link, description: :description, indexed: false, header: "## Search Results")
        return "No results found." if results.nil? || results.empty?

        formatted = results.map.with_index(1) do |r, i|
          title_val = r[title] || r[title.to_s]
          link_val = r[link] || r[link.to_s]
          desc_val = r[description] || r[description.to_s]

          line = indexed ? "#{i}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
          desc_str = desc_val.to_s.strip if desc_val
          desc_str.nil? || desc_str.empty? ? line : "#{line}\n#{desc_val}"
        end

        "#{header}\n\n#{formatted.join("\n\n")}"
      end

      def format_search_results_with_metadata(results, title: "title", link: "link", snippet: "snippet", date: "date")
        return "No results found." if results.nil? || results.empty?

        formatted = results.map.with_index do |r, i|
          parts = ["#{i}. [#{r[title]}](#{r[link]})"]
          parts << "Date: #{r[date]}" if r[date]
          parts << r[snippet] if r[snippet]
          parts.join("\n")
        end

        "## Search Results\n#{formatted.join("\n\n")}"
      end
    end
  end
end
