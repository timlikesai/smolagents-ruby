module Smolagents
  module Concerns
    module Results
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
    end
  end
end
