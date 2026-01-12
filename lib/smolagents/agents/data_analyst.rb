module Smolagents
  module Agents
    class DataAnalyst < Code
      INSTRUCTIONS = <<~TEXT.freeze
        You are a data analysis specialist. Your approach:
        1. Understand the data and the question being asked
        2. Write Ruby code to process, analyze, or transform the data
        3. Use statistical methods when appropriate (mean, median, std, etc.)
        4. Present findings with clear explanations and visualizations when helpful
      TEXT

      def initialize(model:, **)
        super(
          tools: default_tools,
          model: model,
          custom_instructions: INSTRUCTIONS,
          **
        )
      end

      private

      def default_tools
        [
          Smolagents::RubyInterpreterTool.new,
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
