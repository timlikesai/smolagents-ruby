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
      #
      # @overload format_results(results, config)
      #   @param results [Array<Hash>] Results with mapped fields
      #   @param config [Types::ResultFormatConfig] Format configuration
      #   @return [String] Formatted markdown
      #
      # @overload format_results(results, **options)
      #   @param results [Array<Hash>] Results with mapped fields
      #   @param title [Symbol] Key for title field (default: :title)
      #   @param link [Symbol] Key for link field (default: :link)
      #   @param description [Symbol] Key for description field (default: :description)
      #   @param indexed [Boolean] Whether to number results (default: false)
      #   @param header [String] Header text (default: "## Search Results")
      #   @return [String] Formatted markdown
      def format_results(results, config = nil, **)
        return empty_results_message if Array(results).empty?

        cfg = resolve_format_config(config, **)
        formatted = format_result_lines(results, cfg)
        build_results_output(results.size, cfg.header, formatted)
      end

      # Format results with additional metadata fields.
      #
      # @overload format_results_with_metadata(results, config)
      #   @param results [Array<Hash>] Raw results
      #   @param config [Types::ResultFormatConfig] Metadata format configuration
      #   @return [String] Formatted markdown with metadata
      #
      # @overload format_results_with_metadata(results, **options)
      #   @param results [Array<Hash>] Raw results
      #   @param title [String] Key for title field (default: "title")
      #   @param link [String] Key for link field (default: "link")
      #   @param snippet [String] Key for snippet field (default: "snippet")
      #   @param date [String] Key for date field (default: "date")
      #   @return [String] Formatted markdown with metadata
      def format_results_with_metadata(results, config = nil, **)
        return "No results found." if Array(results).empty?

        cfg = resolve_metadata_config(config, **)
        formatted = format_metadata_lines(results, cfg)
        "#{cfg.header}\n#{formatted.join("\n\n")}"
      end

      EMPTY_RESULTS_MESSAGE = <<~MSG.freeze
        ⚠ No results found.

        NEXT STEPS:
        - Try different search terms
        - Try wikipedia for encyclopedic facts
        - If info doesn't exist, say so in final_answer
      MSG

      RESULTS_NEXT_STEPS = <<~MSG.freeze
        NEXT STEPS:
        - If this answers your question, extract relevant info and call final_answer
        - If you need more detail, visit a specific page or search more specifically
      MSG

      private

      def empty_results_message = EMPTY_RESULTS_MESSAGE

      def resolve_format_config(config, **)
        return config if config.is_a?(Types::ResultFormatConfig)

        Types::ResultFormatConfig.create(**)
      end

      def resolve_metadata_config(config, **)
        return config if config.is_a?(Types::ResultFormatConfig)

        Types::ResultFormatConfig.with_metadata(**)
      end

      def format_result_lines(results, config)
        keys = config.field_keys
        results.map.with_index(1) { |result, idx| format_single_result(result, idx, keys, config.indexed?) }
      end

      def format_single_result(result, idx, keys, indexed)
        title_val, link_val = result.values_at(keys[:title], keys[:link])
        line = indexed ? "#{idx}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
        append_description(line, result[keys[:description]])
      end

      def format_metadata_lines(results, config)
        results.map.with_index { |result, idx| format_metadata_line(result, idx, config) }
      end

      def format_metadata_line(result, idx, config)
        parts = [format_link_line(result, idx, config)]
        parts << "Date: #{result[config.date]}" if result[config.date]
        parts << result[config.snippet] if result[config.snippet]
        parts.join("\n")
      end

      def format_link_line(result, idx, config)
        "#{idx}. [#{result[config.title]}](#{result[config.link]})"
      end

      def append_description(line, description)
        desc_str = description.to_s.strip
        desc_str.empty? ? line : "#{line}\n#{description}"
      end

      def build_results_output(count, header, formatted)
        "✓ Found #{count} result#{"s" if count > 1}\n\n#{header}\n\n#{formatted.join("\n\n")}\n\n#{results_next_steps}"
      end

      def results_next_steps = RESULTS_NEXT_STEPS

      def extract_field(result, spec)
        case spec
        in Proc then spec.call(result)
        in Array then result.dig(*spec)
        else result[spec]
        end
      end
    end
  end
end
