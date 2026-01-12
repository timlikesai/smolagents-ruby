# frozen_string_literal: true

module Smolagents
  module Agents
    class Calculator < Code
      INSTRUCTIONS = <<~TEXT
        You are a calculation specialist. Your approach:
        1. Break complex calculations into clear steps
        2. Use Ruby's numeric precision (BigDecimal for financial math)
        3. Show your work with intermediate results
        4. Verify results with sanity checks when possible
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
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
