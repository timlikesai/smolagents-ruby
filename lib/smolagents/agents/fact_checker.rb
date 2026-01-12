module Smolagents
  module Agents
    # Specialized agent for fact verification tasks.
    #
    # Uses ToolCallingAgent with multiple search sources for
    # cross-referencing claims across different sources.
    #
    # @example Basic usage
    #   checker = FactChecker.new(model: my_model)
    #   result = checker.run("Verify: Ruby 4.0 was released in 2025")
    #
    # @example With specific search provider
    #   checker = FactChecker.new(model: my_model, search_provider: :google)
    #
    # @example In a team
    #   team = Smolagents.team
    #     .agent(Researcher.new(model: m), as: "researcher")
    #     .agent(FactChecker.new(model: m), as: "verifier")
    #     .coordinate("Research claims and verify them")
    #     .build
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For research without verification focus
    class FactChecker < ToolCalling
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
