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

      # Override to handle ArXiv's Atom feed format.
      def fetch_results(query:)
        response = make_request(query)
        require_success!(response)
        parse_arxiv_response(response.body)
      end

      private

      def parse_arxiv_response(body)
        require "rexml/document"
        doc = REXML::Document.new(body)

        entries = []
        doc.elements.each("feed/entry") do |entry|
          entries << extract_entry(entry)
        end
        entries
      end

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

      def extract_text(entry, element) = clean_text(extract_raw(entry, element))
      def extract_raw(entry, element) = entry.elements[element]&.text

      def extract_authors(entry)
        authors = []
        entry.elements.each("author/name") { |name| authors << name.text }
        authors.take(5).join(", ") + (authors.size > 5 ? " et al." : "")
      end

      def extract_categories(entry)
        cats = []
        entry.elements.each("category") { |cat| cats << cat.attributes["term"] }
        cats.take(3).join(", ")
      end

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

      def format_paper(paper)
        <<~PAPER.strip
          ## #{paper[:title]}
          **Authors:** #{paper[:authors]}
          **Published:** #{paper[:published]} | **Categories:** #{paper[:categories]}
          **Link:** #{paper[:link]}

          #{truncate_abstract(paper[:abstract])}
        PAPER
      end

      def truncate_abstract(abstract)
        return "" if abstract.nil? || abstract.empty?

        abstract.length > 500 ? "#{abstract[0..497]}..." : abstract
      end
    end
  end

  # Re-export at Smolagents level
  ArxivSearchTool = Tools::ArxivSearchTool
end
