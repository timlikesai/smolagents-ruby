module Smolagents
  module Concerns
    # Result formatting utilities for search and query tools.
    #
    # Provides methods for mapping raw API responses to standardized
    # result formats and rendering them as human-readable markdown.
    #
    # @example Map API results to standard format
    #   class MySearchTool < Tool
    #     include Concerns::Results
    #
    #     def execute(query:)
    #       raw_results = fetch_api(query)
    #       results = map_results(raw_results,
    #         title: "name",
    #         link: "url",
    #         description: "snippet"
    #       )
    #       format_results(results)
    #     end
    #   end
    #
    # @example Field mapping with Procs for transformation
    #   results = map_results(data,
    #     title: "name",
    #     link: ->(r) { "https://example.com/#{r["id"]}" },
    #     description: ->(r) { r["text"]&.truncate(200) }
    #   )
    #
    # @example Extract and map in one step
    #   results = extract_and_map(response,
    #     path: ["data", "items"],
    #     title: "title",
    #     link: "url",
    #     description: "summary"
    #   )
    #
    # @example Format with metadata
    #   format_results_with_metadata(results,
    #     title: "headline",
    #     link: "url",
    #     snippet: "excerpt",
    #     date: "published_at"
    #   )
    #
    # @see SearchTool Which includes this for result formatting
    # @see ToolResult For chainable result wrappers
    module Results
      # Map raw results to standardized field format.
      # @param results [Array<Hash>] Raw result objects
      # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
      #   - String: Key to extract from result
      #   - Proc: Called with result, returns value
      #   - Array: Path for dig-style extraction
      # @return [Array<Hash>] Mapped results with specified keys
      def map_results(results, **fields)
        Array(results).map do |result|
          fields.transform_values { |spec| extract_field(result, spec) }
        end
      end

      # Extract nested results and map to standard format.
      # @param data [Hash] Raw response data
      # @param path [Array<String>] Path to results array (for dig)
      # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
      # @return [Array<Hash>] Mapped results
      def extract_and_map(data, path:, **fields)
        results = data.dig(*path) || []
        map_results(results, **fields)
      end

      # Format results as markdown for display.
      # @param results [Array<Hash>] Results with :title, :link, :description
      # @param title [Symbol] Key for title field (default: :title)
      # @param link [Symbol] Key for link field (default: :link)
      # @param description [Symbol] Key for description field (default: :description)
      # @param indexed [Boolean] Whether to number results (default: false)
      # @param header [String] Header text (default: "## Search Results")
      # @return [String] Formatted markdown
      def format_results(results, title: :title, link: :link, description: :description, indexed: false,
                         header: "## Search Results")
        if Array(results).empty?
          return "⚠ No results found.\n\n" \
                 "NEXT STEPS:\n" \
                 "- Try different search terms\n" \
                 "- Try wikipedia for encyclopedic facts\n" \
                 "- If info doesn't exist, say so in final_answer"
        end

        formatted = results.map.with_index(1) do |result, idx|
          title_val = result[title]
          link_val = result[link]
          desc_val = result[description]

          line = indexed ? "#{idx}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
          desc_str = desc_val.to_s.strip
          desc_str.empty? ? line : "#{line}\n#{desc_val}"
        end

        count = results.size
        "✓ Found #{count} result#{"s" if count > 1}\n\n" \
          "#{header}\n\n#{formatted.join("\n\n")}\n\n" \
          "NEXT STEPS:\n" \
          "- If this answers your question, extract relevant info and call final_answer\n" \
          "- If you need more detail, visit a specific page or search more specifically"
      end

      # Format results with additional metadata fields.
      # @param results [Array<Hash>] Raw results
      # @param title [String] Key for title field (default: "title")
      # @param link [String] Key for link field (default: "link")
      # @param snippet [String] Key for snippet field (default: "snippet")
      # @param date [String] Key for date field (default: "date")
      # @return [String] Formatted markdown with metadata
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
        else result[spec]
        end
      end
    end
  end
end
