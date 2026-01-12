module Smolagents
  module Agents
    # Specialized agent for research tasks.
    #
    # Pre-configured with search, web browsing, and Wikipedia tools.
    # Uses a research-focused instruction set for systematic information gathering.
    #
    # @example Basic usage
    #   researcher = Researcher.new(model: my_model)
    #   result = researcher.run("What are the key features of Ruby 4.0?")
    #
    # @example In a team
    #   team = Smolagents.team
    #     .agent(Researcher.new(model: m), as: "researcher")
    #     .agent(Writer.new(model: m), as: "writer")
    #     .coordinate("Research then write a report")
    #     .build
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see FactChecker For verification-focused research
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
