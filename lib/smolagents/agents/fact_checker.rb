module Smolagents
  module Agents
    # Specialized agent for fact verification tasks.
    #
    # Uses ToolAgent with multiple search sources for cross-referencing
    # claims across different sources. Designed to identify accurate information,
    # detect misinformation, and provide confidence levels.
    #
    # The FactChecker agent is optimized for:
    # - Verifying specific factual claims
    # - Finding corroborating evidence from multiple sources
    # - Identifying contradictions or inconsistencies
    # - Rating confidence levels of verified information
    # - Providing source citations and evidence
    # - Cross-referencing across search and Wikipedia
    #
    # Built-in tools (configurable search provider):
    # - DuckDuckGoSearchTool (default): Balanced search results
    # - BraveSearchTool: Privacy-focused alternative
    # - GoogleSearchTool: Comprehensive coverage (requires API key)
    # - BingSearchTool: Alternative indexing perspective
    # - WikipediaSearchTool: Authoritative encyclopedic reference
    # - VisitWebpageTool: Extract specific content from sources
    # - FinalAnswerTool: Submit verification results with confidence
    #
    # @example Simple fact verification
    #   checker = FactChecker.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = checker.run("Verify: Ruby 4.0 was released in 2025")
    #   puts result.output  # "Yes, Ruby 4.0 was released in..."
    #
    # @example With Brave Search (privacy option)
    #   checker = FactChecker.new(
    #     model: my_model,
    #     search_provider: :brave
    #   )
    #   result = checker.run("Is Python faster than Ruby?")
    #
    # @example With Google Search (comprehensive)
    #   checker = FactChecker.new(
    #     model: my_model,
    #     search_provider: :google
    #   )
    #   result = checker.run("What year was Rails first released?")
    #
    # @example Multi-agent verification pipeline
    #   team = Smolagents.team
    #     .agent(Researcher.new(model: m), as: "researcher")
    #     .agent(FactChecker.new(model: m), as: "verifier")
    #     .coordinate(
    #       "researcher: Find information about recent Ruby releases\n" \
    #       "verifier: Cross-check the findings with multiple sources"
    #     )
    #     .build
    #   result = team.run("Document the Ruby 4.0 release details")
    #
    # @option kwargs [Symbol] :search_provider Search engine to use
    #   Valid values: :duckduckgo (default), :brave, :google, :bing
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    #   Increase for thorough verification (12-15 recommended)
    # @option kwargs [String] :custom_instructions Additional guidance for verification approach
    #
    # @raise [ArgumentError] If search_provider is not recognized
    # @raise [ArgumentError] If model doesn't support tool calling
    #
    # @see Tool Base agent type (JSON tool calling)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For gathering information without verification focus
    # @see Assistant For interactive Q&A with verification
    # @see DuckDuckGoSearchTool Default search tool
    # @see BraveSearchTool Privacy-focused alternative
    # @see GoogleSearchTool Comprehensive search option
    class FactChecker < Tool
      include Concerns::Specialized

      instructions <<~TEXT
        You are a fact-checking specialist. Your approach:
        1. Identify the specific claims to verify
        2. Search multiple sources for corroborating evidence
        3. Cross-reference information across different sources
        4. Rate confidence level and cite sources for each finding
      TEXT

      default_tools do |options|
        search_provider = options[:search_provider] || :duckduckgo
        search_tool = case search_provider
                      when :brave then Smolagents::BraveSearchTool.new
                      when :google then Smolagents::GoogleSearchTool.new
                      when :bing then Smolagents::BingSearchTool.new
                      else Smolagents::DuckDuckGoSearchTool.new
                      end
        [
          search_tool,
          Smolagents::WikipediaSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
