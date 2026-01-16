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
    # @example Basic usage
    #   tool = WikipediaSearchTool.new
    #   result = tool.call(query: "Ruby programming language")
    #   # => ToolResult with article title, intro text, and link
    #
    # @example In an AgentBuilder
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(WikipediaSearchTool.new, :final_answer)
    #     .build
    #   agent.run("What is the headquarters of the New York Times?")
    #
    # @example Multi-language search
    #   tool = WikipediaSearchTool.new(language: "es")
    #   result = tool.call(query: "programacion")
    #   # => Results from Spanish Wikipedia
    #
    # @see DuckDuckGoSearchTool For current events, news, and recent information
    # @see SearchTool Base class for search tools
    # @see Tool Base class for all tools
    class WikipediaSearchTool < SearchTool
      configure do |config|
        config.name "wikipedia"
        config.description <<~DESC.strip
          Search Wikipedia for encyclopedic information. Returns article introductions with key facts.
          Best for: established facts, company info, historical data, definitions.
          Note: Wikipedia may not have the most current information (use web search for breaking news).
        DESC
        config.endpoint { |tool| "https://#{tool.language}.wikipedia.org/w/api.php" }
        config.parses :json
        config.query_param :gsrsearch
        config.query_input_description "Topic, person, company, or subject to look up"
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

      def build_link(title)
        encoded = title.tr(" ", "_")
        "https://#{language}.wikipedia.org/wiki/#{encoded}"
      end

      def format_results(results)
        if results.empty?
          return "⚠ No Wikipedia article found for this query.\n\n" \
                 "NEXT STEPS:\n" \
                 "- Try different search terms\n" \
                 "- Try duckduckgo_search for web results\n" \
                 "- If topic doesn't exist, say so in final_answer"
        end

        formatted = results.take(@max_results).map do |r|
          "## #{r[:title]}\n\n#{r[:extract]}\n\nSource: #{r[:link]}"
        end.join("\n\n---\n\n")

        count = [results.size, @max_results].min
        "✓ Found #{count} Wikipedia article#{"s" if count > 1}\n\n" \
          "#{formatted}\n\n" \
          "NEXT STEPS:\n" \
          "- If this answers your question, extract the relevant info and call final_answer\n" \
          "- If you need more specific info, search for a more specific topic"
      end
    end
  end

  # Re-export WikipediaSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::WikipediaSearchTool
  WikipediaSearchTool = Tools::WikipediaSearchTool
end
