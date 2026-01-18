require_relative "support"

module Smolagents
  module Tools
    # Search Wikipedia for encyclopedic information.
    #
    # Uses Wikipedia's search API with extracts to find relevant articles and
    # return clean, factual introductory content. This combines search (to find
    # matching articles) with extracts (to get readable content).
    #
    # No API key required. Supports multiple languages via the language parameter.
    #
    # **Best for:** Established facts, historical information, definitions, company info.
    # Wikipedia content is well-sourced but may lag behind very recent events.
    # For current information (today's stock price, breaking news), use web search.
    #
    # @example Creating and inspecting the tool
    #   tool = Smolagents::WikipediaSearchTool.new(language: "en", max_results: 3)
    #   tool.name
    #   # => "wikipedia"
    #
    # @see DuckDuckGoSearchTool For current events, news, and recent information
    # @see SearchTool Base class for search tools
    # @see Tool Base class for all tools
    class WikipediaSearchTool < SearchTool
      include Support::FormattedResult
      include Support::ResultTemplates

      configure do |config|
        config.name "wikipedia"
        config.description <<~DESC.strip
          Search Wikipedia for encyclopedic information. Returns article introductions with key facts.
          Best for: established facts, company info, historical data, definitions.
          IMPORTANT: Search for SPECIFIC topics/entities (e.g. "Paris" not "fun facts about Paris").
          Note: Wikipedia may not have the most current information (use web search for breaking news).
        DESC
        config.endpoint { |tool| "https://#{tool.language}.wikipedia.org/w/api.php" }
        config.parses :json
        config.query_param :gsrsearch
        config.query_input_description "Specific topic, person, place, or entity (e.g. 'Paris', 'Ruby programming')"
        config.additional_params(
          action: "query",
          generator: "search",
          gsrnamespace: 0,
          prop: "extracts|info",
          exintro: true,
          explaintext: true,
          inprop: "url",
          format: "json"
        )
        config.results_limit_param :gsrlimit
        config.optional_param :language, default: "en"
      end

      # @param language [String] Wikipedia language code (default: "en")
      # @param max_results [Integer] Maximum number of results (default: 3)
      def initialize(language: "en", max_results: 3, **)
        super
      end

      empty_message <<~MSG.freeze
        No Wikipedia article found for this query.

        NEXT STEPS:
        - Try different search terms
        - Try duckduckgo_search for web results
        - If topic doesn't exist, say so in final_answer
      MSG

      next_steps_message <<~MSG.freeze
        NEXT STEPS:
        - If this answers your question, extract the relevant info and call final_answer
        - If you need more specific info, search for a more specific topic
      MSG

      protected

      # Override to handle Wikipedia's generator search + extracts response format.
      def fetch_results(query:)
        response = make_request(query)
        require_success!(response)
        parse_search_extracts_response(response.body)
      end

      private

      def parse_search_extracts_response(body)
        data = JSON.parse(body)
        pages = data.dig("query", "pages") || {}

        # Filter out missing pages and sort by search index
        pages.values
             .reject { |page| page["pageid"].nil? || page["pageid"].negative? }
             .sort_by { |page| page["index"] || 999 }
             .map { |page| format_page(page) }
      end

      def format_page(page)
        {
          title: page["title"],
          extract: clean_extract(page["extract"]),
          link: page["fullurl"] || build_link(page["title"]),
          pageid: page["pageid"]
        }
      end

      def clean_extract(text)
        return "" unless text

        # Remove excessive whitespace and truncate very long extracts
        text.gsub(/\s+/, " ").strip.slice(0, 2000)
      end

      def build_link(title) = "https://#{language}.wikipedia.org/wiki/#{title.tr(" ", "_")}"

      def format_results(results)
        format_search_results(
          results,
          empty_message: empty_result_message,
          item_formatter: method(:format_article),
          next_steps: next_steps_message
        )
      end

      def format_article(article)
        "## #{article[:title]}\n\n#{article[:extract]}\n\nSource: #{article[:link]}"
      end
    end
  end

  # Re-export WikipediaSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::WikipediaSearchTool
  WikipediaSearchTool = Tools::WikipediaSearchTool
end
