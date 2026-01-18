module Smolagents
  module Tools
    module Support
      # Common result formatting pattern for search tools.
      #
      # Provides a consistent way to format search results with:
      # - Empty result handling with custom messages
      # - Item formatting via blocks
      # - Result count headers
      # - Optional next steps guidance
      #
      # @example Basic usage
      #   include Support::FormattedResult
      #
      #   def format_results(results)
      #     format_search_results(
      #       results,
      #       empty_message: "No articles found.",
      #       item_formatter: ->(r) { "## #{r[:title]}\n#{r[:body]}" },
      #       next_steps: "Try a different query."
      #     )
      #   end
      module FormattedResult
        # Formats search results into a readable string.
        #
        # @param results [Array] The results to format
        # @param empty_message [String] Message to return when results are empty
        # @param item_formatter [Proc] Lambda to format each result item
        # @param next_steps [String, nil] Optional guidance text appended to output
        # @param max_results [Integer] Maximum results to include (default: @max_results)
        # @return [String] Formatted results string
        def format_search_results(results, empty_message:, item_formatter:, next_steps: nil, max_results: nil)
          return empty_message if results.empty?

          limit = max_results || @max_results || results.size
          formatted = results.take(limit).map(&item_formatter).join("\n\n---\n\n")
          count = [results.size, limit].min

          build_result_output(count, formatted, next_steps)
        end

        private

        def build_result_output(count, formatted, next_steps)
          output = "Found #{count} result#{"s" if count > 1}\n\n#{formatted}"
          output += "\n\n#{next_steps}" if next_steps
          output
        end
      end
    end
  end
end
