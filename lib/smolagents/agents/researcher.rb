module Smolagents
  module Agents
    # Specialized agent for research tasks.
    #
    # Pre-configured with search, web browsing, and Wikipedia tools for systematic
    # information gathering. Uses a ToolCallingAgent for reliable JSON-based tool
    # calls suitable for research workflows.
    #
    # The Researcher agent is optimized for:
    # - Gathering factual information from multiple sources
    # - Cross-referencing data across websites and Wikipedia
    # - Synthesizing findings with citations
    # - Building comprehensive overviews of topics
    #
    # Built-in tools:
    # - DuckDuckGoSearchTool: Fast web search with multiple results
    # - VisitWebpageTool: Extract content from specific URLs
    # - WikipediaSearchTool: Authoritative encyclopedic information
    # - FinalAnswerTool: Properly formatted result submission
    #
    # @example Basic research task
    #   researcher = Researcher.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = researcher.run("What are the key features of Ruby 4.0?")
    #   puts result.output
    #
    # @example Research with more time
    #   researcher = Researcher.new(
    #     model: my_model,
    #     max_steps: 20  # Allow more steps for thorough research
    #   )
    #   result = researcher.run(
    #     "Compare programming languages: Ruby vs Python vs Go. " \
    #     "Find recent benchmarks and community statistics."
    #   )
    #
    # @example In a multi-agent team
    #   team = Smolagents.team
    #     .agent(Researcher.new(model: m), as: "researcher")
    #     .agent(FactChecker.new(model: m), as: "verifier")
    #     .agent(Writer.new(model: m), as: "writer")
    #     .coordinate(
    #       "researcher: gather information\n" \
    #       "verifier: check facts\n" \
    #       "writer: synthesize into report"
    #     )
    #     .build
    #   result = team.run("Write a report on Ruby's ecosystem")
    #
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    #   Increase for complex research topics (15-20 recommended)
    # @option kwargs [String] :custom_instructions Additional guidance beyond
    #   the default research instructions
    #
    # @raise [ArgumentError] If model doesn't support tool calling
    #
    # @see ToolCalling Base agent type (JSON tool calling)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see FactChecker For verification-focused research with cross-checking
    # @see WebScraper For extracting structured data from pages
    # @see Assistant For interactive research with clarifying questions
    class Researcher < ToolCalling
      include Concerns::Specialized

      instructions <<~TEXT
        You are a research specialist. Your approach:
        1. Search for relevant information on the topic
        2. Gather detailed facts from promising sources
        3. Cross-reference information across sources
        4. Summarize findings with citations
      TEXT

      default_tools do |_options|
        [
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::WikipediaSearchTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
