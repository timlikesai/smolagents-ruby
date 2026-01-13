module Smolagents
  module Agents
    # Specialized agent for web content extraction and scraping.
    #
    # Uses CodeAgent with search, web browsing, and Ruby processing for
    # structured extraction from web pages. Ideal for parsing HTML, cleaning data,
    # and converting unstructured web content into usable formats.
    #
    # The WebScraper agent is optimized for:
    # - Extracting structured data from HTML pages
    # - Finding and visiting multiple relevant pages
    # - Parsing and cleaning raw HTML content
    # - Converting unstructured data to JSON, CSV, or structured formats
    # - Handling pagination and multi-page extraction
    # - Deduplicating and organizing results
    #
    # Built-in tools:
    # - DuckDuckGoSearchTool: Find relevant pages to scrape
    # - VisitWebpageTool: Fetch page content in text/markdown format
    # - RubyInterpreterTool: Parse, clean, and structure extracted data
    #   - Use Nokogiri for HTML parsing (included in authorized imports)
    #   - Use JSON/CSV for output formatting
    #   - Apply regex for text extraction
    #   - Deduplicate and sort results
    # - FinalAnswerTool: Submit structured results
    #
    # @example Extract article titles
    #   scraper = WebScraper.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = scraper.run("Extract article titles from Hacker News")
    #   puts result.output
    #
    # @example Multi-page scraping with data cleaning
    #   result = scraper.run(
    #     "Find all Ruby gem reviews on RubyGems.org for the 'Rails' gem. " \
    #     "Extract reviewer names, ratings, and review text. " \
    #     "Remove duplicates and organize by rating."
    #   )
    #
    # @example Product information extraction
    #   result = scraper.run(
    #     "Visit product pages for the top 5 smartphones. " \
    #     "Extract: name, price, specs (processor, RAM, storage), and ratings. " \
    #     "Format as CSV."
    #   )
    #
    # @example Social media data collection
    #   result = scraper.run(
    #     "Search for recent articles about 'machine learning trends'. " \
    #     "From each article, extract: title, publication date, author, summary. " \
    #     "Return as JSON with 'articles' array."
    #   )
    #
    # @example Price comparison task
    #   result = scraper.run(
    #     "Find prices for 'MacBook Pro' on Amazon, Best Buy, and Apple Store. " \
    #     "Extract model, specs, and price from each site. " \
    #     "Create a comparison table (HTML or markdown)."
    #   )
    #
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    #   Increase for complex multi-page scraping (15-20 recommended)
    # @option kwargs [String] :custom_instructions Additional guidance for scraping approach
    #
    # @raise [ArgumentError] If model cannot generate valid Ruby code for parsing
    #
    # @see Code Base agent type (Ruby code execution)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For gathering information without code-based extraction
    # @see DataAnalyst For analyzing structured data
    # @see VisitWebpageTool For fetching individual pages
    # @see DuckDuckGoSearchTool For finding pages to scrape
    class WebScraper < Code
      include Concerns::Specialized

      instructions <<~TEXT
        You are a web content extraction specialist. Your approach:
        1. Search for relevant pages on the topic
        2. Visit pages and extract structured content
        3. Process and clean the extracted data with Ruby
        4. Return well-formatted, organized results
      TEXT

      default_tools do |_options|
        [
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
