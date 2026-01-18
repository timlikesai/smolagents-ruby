require_relative "support"

module Smolagents
  module Tools
    # Search ArXiv for academic papers and preprints.
    #
    # Uses ArXiv's public API (no authentication required) to search for
    # papers by title, abstract, author, or category. Returns paper titles,
    # abstracts, authors, and links.
    #
    # **Best for:** Academic research, AI/ML papers, scientific literature,
    # finding state-of-the-art techniques and methodologies.
    #
    # @example Creating and inspecting the tool
    #   tool = Smolagents::ArxivSearchTool.new(max_results: 5)
    #   tool.name
    #   # => "arxiv"
    #
    # ArXiv categories relevant to agents:
    # - cs.AI (Artificial Intelligence)
    # - cs.CL (Computation and Language / NLP)
    # - cs.LG (Machine Learning)
    # - cs.MA (Multiagent Systems)
    #
    # @see https://arxiv.org/help/api/user-manual ArXiv API documentation
    class ArxivSearchTool < SearchTool
      include Support::FormattedResult
      include Support::ResultTemplates

      configure do |config|
        config.name "arxiv"
        config.description <<~DESC.strip
          Search ArXiv for academic papers and preprints. Returns titles, abstracts, authors, and links.
          Best for: AI/ML research, finding papers on techniques like ReAct, Chain-of-Thought, tool use.
          Tip: Use terms like "language model", "agent", "tool use", "prompting" for relevant results.
        DESC
        config.endpoint "https://export.arxiv.org/api/query"
        config.parses :xml
        config.query_param :search_query
        config.query_input_description "Search terms (e.g., 'ReAct agent', 'tool use language model')"
        config.additional_params(
          sortBy: "relevance",
          sortOrder: "descending"
        )
        config.results_limit_param :max_results
        config.max_results_limit 10
      end

      # @param max_results [Integer] Maximum papers to return (default: 5, max: 10)
      def initialize(max_results: 5, **)
        super
      end

      empty_message <<~MSG.freeze
        No ArXiv papers found for this query.

        NEXT STEPS:
        - Try broader search terms
        - Try related terms (e.g., 'LLM' instead of 'language model')
        - Search Wikipedia for overview, then ArXiv for papers
      MSG

      next_steps_message <<~MSG.freeze
        NEXT STEPS:
        - If these papers answer your question, summarize key findings in final_answer
        - For more papers, try different search terms
        - Note key techniques mentioned for further research
      MSG

      protected

      # Fetches results from ArXiv's Atom feed API.
      #
      # @param query [String] Search query
      # @return [Array<Hash>] Parsed paper entries with title, abstract, authors, etc
      def fetch_results(query:)
        response = make_request(query)
        require_success!(response)
        parse_arxiv_response(response.body)
      end

      private

      # Parses ArXiv Atom feed XML response into structured paper entries.
      #
      # @param body [String] XML response body from ArXiv API
      # @return [Array<Hash>] Extracted paper entries
      def parse_arxiv_response(body)
        require "rexml/document"
        doc = REXML::Document.new(body)

        entries = []
        doc.elements.each("feed/entry") do |entry|
          entries << extract_entry(entry)
        end
        entries
      end

      # Extracts structured paper data from an ArXiv feed entry.
      #
      # @param entry [REXML::Element] Atom feed entry element
      # @return [Hash] Paper data with title, abstract, authors, link, published, categories
      def extract_entry(entry)
        {
          title: extract_text(entry, "title"),
          abstract: extract_text(entry, "summary"),
          authors: extract_authors(entry),
          link: extract_raw(entry, "id"),
          published: extract_raw(entry, "published")&.slice(0, 10),
          categories: extract_categories(entry)
        }
      end

      # Extracts and cleans text from an XML element.
      #
      # @param entry [REXML::Element] Parent element
      # @param element [String] Child element name to extract
      # @return [String] Cleaned and normalized text
      def extract_text(entry, element) = clean_text(extract_raw(entry, element))

      # Extracts raw text from an XML element.
      #
      # @param entry [REXML::Element] Parent element
      # @param element [String] Child element name
      # @return [String, nil] Raw text content or nil
      def extract_raw(entry, element) = entry.elements[element]&.text

      # Extracts author list from a paper entry, limiting to 5 with "et al." suffix.
      #
      # @param entry [REXML::Element] Paper entry element
      # @return [String] Comma-separated author list
      def extract_authors(entry)
        authors = []
        entry.elements.each("author/name") { |name| authors << name.text }
        authors.take(5).join(", ") + (authors.size > 5 ? " et al." : "")
      end

      # Extracts category tags from a paper entry.
      #
      # @param entry [REXML::Element] Paper entry element
      # @return [String] Comma-separated list of up to 3 categories
      def extract_categories(entry)
        cats = []
        entry.elements.each("category") { |cat| cats << cat.attributes["term"] }
        cats.take(3).join(", ")
      end

      # Cleans text by normalizing whitespace.
      #
      # @param text [String, nil] Text to clean
      # @return [String] Cleaned text with normalized whitespace
      def clean_text(text)
        return "" unless text

        text.gsub(/\s+/, " ").strip
      end

      def format_results(results)
        format_search_results(
          results,
          empty_message: empty_result_message,
          item_formatter: method(:format_paper),
          next_steps: next_steps_message
        )
      end

      # Formats a paper into markdown for presentation.
      #
      # @param paper [Hash] Paper data with title, authors, abstract, etc
      # @return [String] Formatted markdown representation
      def format_paper(paper)
        <<~PAPER.strip
          ## #{paper[:title]}
          **Authors:** #{paper[:authors]}
          **Published:** #{paper[:published]} | **Categories:** #{paper[:categories]}
          **Link:** #{paper[:link]}

          #{truncate_abstract(paper[:abstract])}
        PAPER
      end

      # Truncates abstract to 500 characters with ellipsis.
      #
      # @param abstract [String, nil] Paper abstract text
      # @return [String] Truncated abstract or empty string
      def truncate_abstract(abstract)
        return "" if abstract.nil? || abstract.empty?

        abstract.length > 500 ? "#{abstract[0..497]}..." : abstract
      end
    end
  end

  # Re-export at Smolagents level
  ArxivSearchTool = Tools::ArxivSearchTool
end
