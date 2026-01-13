module Smolagents
  module Agents
    # Specialized agent for mathematical calculations.
    #
    # Uses CodeAgent with Ruby interpreter for precise calculations. Ideal for
    # mathematical problems, financial computations, and numerical analysis.
    #
    # The Calculator agent is optimized for:
    # - Complex arithmetic and scientific calculations
    # - Financial computations with BigDecimal precision
    # - Step-by-step problem solving with intermediate results
    # - Verification of results through sanity checks
    # - Custom algorithmic solutions (factorials, fibonacci, etc.)
    #
    # Built-in tools:
    # - RubyInterpreterTool: Execute arbitrary Ruby code for calculations
    # - FinalAnswerTool: Submit and format the final result
    #
    # Code execution provides:
    # - Full access to Ruby's Math module (sin, cos, log, etc.)
    # - Arbitrary precision with BigDecimal
    # - Variable storage across steps
    # - Loops and conditionals for iterative calculations
    #
    # @example Simple arithmetic
    #   calculator = Calculator.new(model: OpenAIModel.new(model_id: "gpt-4"))
    #   result = calculator.run("What is 2^20?")
    #   puts result.output  # "1048576"
    #
    # @example Financial calculation
    #   result = calculator.run(
    #     "Calculate compound interest: $10,000 principal at 5% annual rate for 10 years. " \
    #     "Show year-by-year growth and final amount."
    #   )
    #
    # @example Complex problem with verification
    #   result = calculator.run(
    #     "Find the 10th Fibonacci number. " \
    #     "Show the sequence and verify the result is correct."
    #   )
    #
    # @example Statistical calculation
    #   result = calculator.run(
    #     "Given data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], " \
    #     "calculate mean, median, standard deviation, and variance."
    #   )
    #
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    # @option kwargs [String] :custom_instructions Additional guidance for calculation approach
    #
    # @raise [ArgumentError] If model cannot generate valid Ruby code
    #
    # @see Code Base agent type (Ruby code execution)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see DataAnalyst For data analysis with search and statistics
    # @see RubyInterpreterTool Direct access to Ruby interpreter without agent overhead
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
