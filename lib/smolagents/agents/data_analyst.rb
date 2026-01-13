module Smolagents
  module Agents
    # Specialized agent for data analysis tasks.
    #
    # Uses CodeAgent with Ruby interpreter for data processing, statistical analysis,
    # and visualization. Can search for external data when needed.
    #
    # The DataAnalyst agent is optimized for:
    # - Statistical analysis (mean, median, std dev, variance, correlation)
    # - Data transformation and cleaning
    # - Pattern discovery in datasets
    # - Comparative analysis
    # - Data visualization recommendations
    # - Integration with external data sources via search
    #
    # Built-in tools:
    # - RubyInterpreterTool: Execute data processing code, statistical calculations
    # - DuckDuckGoSearchTool: Find and fetch external data sources
    # - FinalAnswerTool: Submit formatted results with insights
    #
    # Code execution provides:
    # - Full Ruby environment for data processing
    # - Enumerable methods (map, select, reduce, etc.)
    # - Math operations and statistical functions
    # - Array and Hash manipulation
    # - JSON parsing for external data
    #
    # @example Basic analysis
    #   analyst = DataAnalyst.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = analyst.run("Analyze: [1,2,3,4,5] - find mean, median, std dev")
    #   puts result.output
    #
    # @example Analysis with external data
    #   result = analyst.run(
    #     "Find Ruby gem download statistics for Rails, " \
    #     "Sinatra, and Hanami. Analyze growth trends and market share."
    #   )
    #
    # @example Comparative analysis
    #   result = analyst.run(
    #     "Compare programming language popularity: " \
    #     "Find recent survey data and analyze trends over time."
    #   )
    #
    # @example Data transformation task
    #   result = analyst.run(
    #     "You have CSV data with employee names, salaries, and departments. " \
    #     "Parse it and analyze salary distribution by department. " \
    #     "Find anomalies."
    #   )
    #
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    #   Increase for complex analysis (15-20 recommended)
    # @option kwargs [String] :custom_instructions Additional guidance for analysis approach
    #
    # @raise [ArgumentError] If model cannot generate valid Ruby code
    #
    # @see Code Base agent type (Ruby code execution)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Calculator For pure mathematical calculations
    # @see WebScraper For extracting and structuring data from HTML
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
