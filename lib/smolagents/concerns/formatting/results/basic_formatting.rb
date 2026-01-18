module Smolagents
  module Concerns
    module Results
      # Basic result formatting as markdown.
      #
      # Renders results with title, link, and optional description
      # in a simple markdown format with optional numbering.
      #
      # @example Simple format
      #   [Title](http://link.com)
      #   Description text here
      #
      # @example Indexed format
      #   1. [Title](http://link.com)
      #   Description text here
      module BasicFormatting
        # Format results as markdown for display.
        #
        # @param results [Array<Hash>] Results with mapped fields
        # @param config [Types::ResultFormatConfig, nil] Format configuration
        # @param title [Symbol] Key for title field (default: :title)
        # @param link [Symbol] Key for link field (default: :link)
        # @param description [Symbol] Key for description field (default: :description)
        # @param indexed [Boolean] Whether to number results (default: false)
        # @param header [String] Header text (default: "## Search Results")
        # @return [String] Formatted markdown
        def format_results(results, config = nil, **)
          return empty_results_message if Array(results).empty?

          cfg = resolve_format_config(config, **)
          formatted = format_result_lines(results, cfg)
          build_results_output(results.size, cfg.header, formatted)
        end

        private

        # Resolve config from object or keyword arguments.
        #
        # @param config [Types::ResultFormatConfig, nil]
        # @return [Types::ResultFormatConfig]
        def resolve_format_config(config, **)
          return config if config.is_a?(Types::ResultFormatConfig)

          Types::ResultFormatConfig.create(**)
        end

        # Format all results into markdown lines.
        #
        # @param results [Array<Hash>]
        # @param config [Types::ResultFormatConfig]
        # @return [Array<String>]
        def format_result_lines(results, config)
          keys = config.field_keys
          results.map.with_index(1) do |result, idx|
            format_single_result(result, idx, keys, config.indexed?)
          end
        end

        # Format a single result entry.
        #
        # @param result [Hash] Single result
        # @param idx [Integer] 1-based index
        # @param keys [Hash] Field key mappings
        # @param indexed [Boolean] Whether to show index
        # @return [String]
        def format_single_result(result, idx, keys, indexed)
          title_val = result[keys[:title]]
          link_val = result[keys[:link]]
          line = indexed ? "#{idx}. [#{title_val}](#{link_val})" : "[#{title_val}](#{link_val})"
          append_description(line, result[keys[:description]])
        end

        # Append description to a result line if present.
        #
        # @param line [String] Result line
        # @param description [String, nil] Description text
        # @return [String]
        def append_description(line, description)
          desc_str = description.to_s.strip
          desc_str.empty? ? line : "#{line}\n#{description}"
        end
      end
    end
  end
end
