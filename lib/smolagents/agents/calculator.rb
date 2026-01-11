module Smolagents
  module Agents
    class Calculator < Code
      INSTRUCTIONS = <<~INSTRUCTIONS
        You are a calculation specialist. Your approach:
        1. Break complex calculations into clear steps
        2. Use Ruby's numeric precision (BigDecimal for financial math)
        3. Show your work with intermediate results
        4. Verify results with sanity checks when possible
      INSTRUCTIONS

      def initialize(model:, **opts)
        tools = [
          Tools::RubyInterpreterTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, custom_instructions: INSTRUCTIONS, **opts)
      end
    end
  end
end
