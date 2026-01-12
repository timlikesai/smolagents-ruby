module Smolagents
  module Agents
    # Specialized agent for mathematical calculations.
    #
    # Uses CodeAgent with Ruby interpreter for precise calculations.
    # Supports complex math, BigDecimal for financial precision, and step-by-step work.
    #
    # @example Basic usage
    #   calculator = Calculator.new(model: my_model)
    #   result = calculator.run("Calculate compound interest: $10000 at 5% for 10 years")
    #
    # @example In AgentBuilder style
    #   # Equivalent to Calculator but with custom config:
    #   agent = Smolagents.agent(:code)
    #     .model { my_model }
    #     .tools(:ruby_interpreter, :final_answer)
    #     .instructions("You are a calculation specialist...")
    #     .build
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see DataAnalyst For data analysis with search capabilities
    class Calculator < Code
      include Concerns::Specialized

      instructions <<~TEXT
        You are a calculation specialist. Your approach:
        1. Break complex calculations into clear steps
        2. Use Ruby's numeric precision (BigDecimal for financial math)
        3. Show your work with intermediate results
        4. Verify results with sanity checks when possible
      TEXT

      default_tools do |_options|
        [
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
