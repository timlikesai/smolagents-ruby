module Smolagents
  module Concerns
    # Result formatting utilities for search and query tools.
    #
    # Provides methods for mapping raw API responses to standardized
    # result formats and rendering them as human-readable markdown.
    #
    # == Methods
    #
    # - Extraction: map_results(), extract_and_map(), extract_field()
    # - Messages: EMPTY_RESULTS_MESSAGE, build_results_output()
    # - Formatting: format_results(), format_results_with_metadata()
    # - SearchFormatting: format_search_results() with custom item formatter
    #
    # @example Map API results to standard format
    #   class MySearchTool < Tool
    #     include Concerns::Results
    #
    #     def execute(query:)
    #       raw_results = fetch_api(query)
    #       results = map_results(raw_results, title: "name", link: "url")
    #       format_results(results)
    #     end
    #   end
    #
    # @example Format with metadata
    #   format_results(results, include_metadata: true, date: "published_at")
    module Results
      # Field extraction from raw API responses.
      #
      # Handles mapping raw result hashes to standardized formats using
      # string keys, array paths (for dig), or Procs for transformation.
      module Extraction
        # Map raw results to standardized field format.
        #
        # @param results [Array<Hash>] Raw result objects
        # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
        # @return [Array<Hash>] Mapped results with specified keys
        def map_results(results, **fields)
          Array(results).map do |result|
            fields.transform_values { |spec| extract_field(result, spec) }
          end
        end

        # Extract nested results and map to standard format.
        #
        # @param data [Hash] Raw response data
        # @param path [Array<String>] Path to results array (for dig)
        # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
        # @return [Array<Hash>] Mapped results
        def extract_and_map(data, path:, **fields)
          results = data.dig(*path) || []
          map_results(results, **fields)
        end

        private

        # Extract a single field value using the given spec.
        #
        # @param result [Hash] Single result object
        # @param spec [String, Proc, Array] Extraction specification
        # @return [Object] Extracted value
        def extract_field(result, spec)
          case spec
          in Proc then spec.call(result)
          in Array then result.dig(*spec)
          else result[spec]
          end
        end
      end

      # Output message templates for search results.
      #
      # Provides constants and helpers for generating consistent
      # user-facing messages when displaying search results.
      module Messages
        EMPTY_RESULTS_MESSAGE = <<~MSG.freeze
          No results found.

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

        # Hash-driven message configuration for extensibility.
        MESSAGE_TEMPLATES = {
          empty: EMPTY_RESULTS_MESSAGE,
          next_steps: RESULTS_NEXT_STEPS
        }.freeze

        private

        # Returns the empty results message.
        # @return [String] Message shown when no results found
        def empty_results_message = EMPTY_RESULTS_MESSAGE

        # Returns the next steps guidance.
        # @return [String] Message shown after results
        def results_next_steps = RESULTS_NEXT_STEPS

        # Build the full output with result count, header, and next steps.
        #
        # @param count [Integer] Number of results
        # @param header [String] Section header
        # @param formatted [Array<String>] Formatted result lines
        # @return [String] Complete output
        def build_results_output(count, header, formatted)
          result_word = count == 1 ? "result" : "results"
          "Found #{count} #{result_word}\n\n#{header}\n\n#{formatted.join("\n\n")}\n\n#{results_next_steps}"
        end
      end

      # Unified result formatting as markdown.
      #
      # Renders results with title, link, and optional metadata fields.
      # Use `include_metadata: true` for rich formatting with date/snippet.
      module Formatting
        # Format results as markdown.
        #
        # @param results [Array<Hash>] Results with mapped fields
        # @param config [Types::ResultFormatConfig, nil] Format configuration
        # @param include_metadata [Boolean] Enable metadata fields (default: false)
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

      # Custom item formatter for search results.
      #
      # Use when results require domain-specific rendering (papers, articles).
      # Provides the same API as Tools::Support::FormattedResult.
      module SearchFormatting
        # Format search results with custom item formatter.
        #
        # @param results [Array] Results to format
        # @param empty_message [String] Message when results are empty
        # @param item_formatter [Proc] Lambda to format each result item
        # @param next_steps [String, nil] Optional guidance appended to output
        # @param max_results [Integer, nil] Maximum results (uses @max_results if nil)
        # @return [String] Formatted results string
        def format_search_results(results, empty_message:, item_formatter:, next_steps: nil, max_results: nil)
          return empty_message if results.empty?

          limit = max_results || instance_variable_get(:@max_results) || results.size
          formatted = results.take(limit).map(&item_formatter).join("\n\n---\n\n")
          build_search_output([results.size, limit].min, formatted, next_steps)
        end

        private

        def build_search_output(count, formatted, next_steps)
          output = "Found #{count} result#{"s" if count > 1}\n\n#{formatted}"
          next_steps ? "#{output}\n\n#{next_steps}" : output
        end
      end

      def self.included(base)
        base.include(Results::Extraction)
        base.include(Results::Messages)
        base.include(Results::Formatting)
        base.include(Results::SearchFormatting)
      end
    end
  end
end
