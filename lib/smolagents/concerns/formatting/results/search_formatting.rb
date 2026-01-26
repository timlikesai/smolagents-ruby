module Smolagents
  module Concerns
    module Results
      # Custom item formatter for search results.
      #
      # Use when results require domain-specific rendering (papers, articles).
      # Provides the same API as Tools::Support::FormattedResult.
      #
      # @example
      #   format_search_results(
      #     results,
      #     empty_message: "No papers found.",
      #     item_formatter: ->(r) { "## #{r[:title]}\n#{r[:body]}" },
      #     next_steps: "Try different terms."
      #   )
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
    end
  end
end
