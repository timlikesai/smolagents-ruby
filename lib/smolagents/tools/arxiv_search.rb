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
    # @example Basic usage
    #   tool = ArxivSearchTool.new
    #   result = tool.call(query: "language model tool use")
    #   # => Papers about LLM tool usage
    #
    # @example Search specific categories
    #   tool = ArxivSearchTool.new
    #   result = tool.call(query: "cat:cs.AI AND reinforcement learning")
    #
    # @example In an agent
    #   agent = Smolagents.agent
    #     .model { gemma }
    #     .tools(ArxivSearchTool.new, :wikipedia, :final_answer)
    #     .build
    #   agent.run("What are the latest papers on ReAct agents?")
    #
    # ArXiv categories relevant to agents:
    # - cs.AI (Artificial Intelligence)
    # - cs.CL (Computation and Language / NLP)
    # - cs.LG (Machine Learning)
    # - cs.MA (Multiagent Systems)
    #
    # @see https://arxiv.org/help/api/user-manual ArXiv API documentation
    class ArxivSearchTool < SearchTool
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
          title: clean_text(entry.elements["title"]&.text),
          abstract: clean_text(entry.elements["summary"]&.text),
          authors: extract_authors(entry),
          link: entry.elements["id"]&.text,
          published: entry.elements["published"]&.text&.slice(0, 10),
          categories: extract_categories(entry)
        }
      end

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
        if results.empty?
          return "⚠ No ArXiv papers found for this query.\n\n" \
                 "NEXT STEPS:\n" \
                 "- Try broader search terms\n" \
                 "- Try related terms (e.g., 'LLM' instead of 'language model')\n" \
                 "- Search Wikipedia for overview, then ArXiv for papers"
        end

        formatted = results.take(@max_results).map do |paper|
          <<~PAPER.strip
            ## #{paper[:title]}
            **Authors:** #{paper[:authors]}
            **Published:** #{paper[:published]} | **Categories:** #{paper[:categories]}
            **Link:** #{paper[:link]}

            #{truncate_abstract(paper[:abstract])}
          PAPER
        end.join("\n\n---\n\n")

        count = [results.size, @max_results].min
        "✓ Found #{count} ArXiv paper#{"s" if count > 1}\n\n" \
          "#{formatted}\n\n" \
          "NEXT STEPS:\n" \
          "- If these papers answer your question, summarize key findings in final_answer\n" \
          "- For more papers, try different search terms\n" \
          "- Note key techniques mentioned for further research"
      end

      def truncate_abstract(abstract)
        return "" if abstract.nil? || abstract.empty?

        if abstract.length > 500
          "#{abstract[0..497]}..."
        else
          abstract
        end
      end
    end
  end

  # Re-export at Smolagents level
  ArxivSearchTool = Tools::ArxivSearchTool
end
