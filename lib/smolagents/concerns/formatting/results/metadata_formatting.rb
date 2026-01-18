module Smolagents
  module Concerns
    module Results
      # Metadata-rich result formatting.
      #
      # Renders results with additional metadata fields like date,
      # snippet, etc. in an indexed markdown format.
      #
      # @example Metadata format
      #   1. [Title](http://link.com)
      #   Date: 2024-01-15
      #   Snippet text here
      module MetadataFormatting
        # Format results with additional metadata fields.
        #
        # @param results [Array<Hash>] Raw results
        # @param config [Types::ResultFormatConfig, nil] Metadata format configuration
        # @param title [String] Key for title field (default: "title")
        # @param link [String] Key for link field (default: "link")
        # @param snippet [String] Key for snippet field (default: "snippet")
        # @param date [String] Key for date field (default: "date")
        # @return [String] Formatted markdown with metadata
        def format_results_with_metadata(results, config = nil, **)
          return "No results found." if Array(results).empty?

          cfg = resolve_metadata_config(config, **)
          formatted = format_metadata_lines(results, cfg)
          "#{cfg.header}\n#{formatted.join("\n\n")}"
        end

        private

        # Resolve metadata config from object or keyword arguments.
        #
        # @param config [Types::ResultFormatConfig, nil]
        # @return [Types::ResultFormatConfig]
        def resolve_metadata_config(config, **)
          return config if config.is_a?(Types::ResultFormatConfig)

          Types::ResultFormatConfig.with_metadata(**)
        end

        # Format all results with metadata into lines.
        #
        # @param results [Array<Hash>]
        # @param config [Types::ResultFormatConfig]
        # @return [Array<String>]
        def format_metadata_lines(results, config)
          results.map.with_index(1) do |result, idx|
            format_metadata_line(result, idx, config)
          end
        end

        # Format a single result with metadata.
        #
        # @param result [Hash] Single result
        # @param idx [Integer] 1-based index
        # @param config [Types::ResultFormatConfig]
        # @return [String]
        def format_metadata_line(result, idx, config)
          parts = [format_link_line(result, idx, config)]
          parts << "Date: #{result[config.date]}" if result[config.date]
          parts << result[config.snippet] if result[config.snippet]
          parts.join("\n")
        end

        # Format the title/link line for metadata results.
        #
        # @param result [Hash]
        # @param idx [Integer]
        # @param config [Types::ResultFormatConfig]
        # @return [String]
        def format_link_line(result, idx, config)
          "#{idx}. [#{result[config.title]}](#{result[config.link]})"
        end
      end
    end
  end
end
