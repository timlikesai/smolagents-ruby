module Smolagents
  module Concerns
    module Results
      # Unified result formatting as markdown.
      #
      # Renders results with title, link, and optional metadata fields.
      # Use `include_metadata: true` for rich formatting with date/snippet.
      #
      # @example Basic format
      #   format_results(results, indexed: true)
      #   # 1. [Title](http://link.com)
      #   # Description text
      #
      # @example Metadata format
      #   format_results(results, include_metadata: true)
      #   # 1. [Title](http://link.com)
      #   # Date: 2024-01-15
      #   # Snippet text
      module Formatting
        # Format results as markdown.
        #
        # @param results [Array<Hash>] Results with mapped fields
        # @param config [Types::ResultFormatConfig, nil] Format configuration
        # @param include_metadata [Boolean] Enable metadata fields (default: false)
        # @param title [Symbol] Key for title field (default: :title)
        # @param link [Symbol] Key for link field (default: :link)
        # @param description [Symbol, nil] Key for description field
        # @param snippet [Symbol, nil] Key for snippet field
        # @param date [Symbol, nil] Key for date field
        # @param indexed [Boolean] Whether to number results
        # @param header [String] Header text
        # @return [String] Formatted markdown
        def format_results(results, config = nil, include_metadata: false, **)
          return empty_results_message if Array(results).empty?

          cfg = resolve_format_config(config, include_metadata:, **)
          formatted = format_result_lines(results, cfg)
          build_results_output(results.size, cfg.header, formatted)
        end

        # Format results with additional metadata fields.
        # Convenience alias for format_results(results, include_metadata: true, ...).
        def format_results_with_metadata(results, config = nil, **)
          format_results(results, config, include_metadata: true, **)
        end

        private

        def resolve_format_config(config, include_metadata: false, **)
          return config if config.is_a?(Types::ResultFormatConfig)

          include_metadata ? Types::ResultFormatConfig.with_metadata(**) : Types::ResultFormatConfig.create(**)
        end

        def format_result_lines(results, config)
          results.map.with_index(1) { |result, idx| format_result_line(result, idx, config) }
        end

        def format_result_line(result, idx, config)
          config.metadata_format? ? format_with_metadata(result, idx, config) : format_basic(result, idx, config)
        end

        def format_basic(result, idx, config)
          keys = config.field_keys
          title_val = result[keys[:title]]
          link_val = result[keys[:link]]
          line = config.indexed? ? "#{idx}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
          append_description(line, result[keys[:description]])
        end

        def format_with_metadata(result, idx, config)
          parts = ["#{idx}. [#{result[config.title]}](#{result[config.link]})"]
          parts << "Date: #{result[config.date]}" if result[config.date]
          parts << result[config.snippet] if result[config.snippet]
          parts.join("\n")
        end

        def append_description(line, description)
          desc_str = description.to_s.strip
          desc_str.empty? ? line : "#{line}\n#{description}"
        end
      end
    end
  end
end
