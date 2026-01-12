module Smolagents
  module Agents
    # Specialized agent for data analysis tasks.
    #
    # Uses CodeAgent with Ruby interpreter for data processing, statistical
    # analysis, and visualization. Can search for context when needed.
    #
    # @example Basic usage
    #   analyst = DataAnalyst.new(model: my_model)
    #   result = analyst.run("Analyze this data: [1,2,3,4,5] - find mean, median, std")
    #
    # @example With search for context
    #   result = analyst.run("Find and analyze Ruby gem download statistics")
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Calculator For pure calculation tasks
    class DataAnalyst < Code
      include Concerns::Specialized

      instructions <<~TEXT
        You are a data analysis specialist. Your approach:
        1. Understand the data and the question being asked
        2. Write Ruby code to process, analyze, or transform the data
        3. Use statistical methods when appropriate (mean, median, std, etc.)
        4. Present findings with clear explanations and visualizations when helpful
      TEXT

      default_tools do |_options|
        [
          Smolagents::RubyInterpreterTool.new,
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
