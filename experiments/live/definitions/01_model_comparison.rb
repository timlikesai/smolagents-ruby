# Experiment: Model Comparison
#
# Compare different models on the same tasks to understand their strengths.

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:model_comparison) do
  description "Compare local models on reasoning, math, and tool use tasks"

  models do
    use :fast_20b, :fast_model
    use :coder_30b, :reasoning_model
    use :utility, :utility_model
  end

  tools do
    mock :calculate, "Calculate a mathematical expression", expression: String do |expression:|
      begin
        # Safe math evaluation - only allow numbers and basic operators
        sanitized = expression.to_s.gsub(/[^0-9+\-*\/().\s]/, "").strip

        # Validate it starts with a number or parenthesis
        if sanitized.empty? || sanitized !~ /\A[\d(]/
          "Error: invalid expression '#{expression}'"
        else
          eval(sanitized).to_s # rubocop:disable Security/Eval -- controlled input
        end
      rescue StandardError => e
        "Error: could not evaluate '#{expression}' - #{e.message}"
      end
    end

    mock :search, "Search for information", query: String do |query:|
      # Simulated search results
      "Search results for '#{query}':\n" \
        "1. Wikipedia article about #{query}\n" \
        "2. Research paper on #{query} fundamentals\n" \
        "3. Tutorial: Getting started with #{query}"
    end
  end

  tasks do
    # Arithmetic
    task "What is 15 * 7?",
         expect: "105",
         tags: [:arithmetic, :simple],
         difficulty: :easy

    task "Calculate (23 + 17) * 4 - 50",
         expect: "110",
         tags: [:arithmetic, :compound],
         difficulty: :medium

    task "What is the result of 144 / 12 + 8 * 3?",
         expect: "36",
         tags: [:arithmetic, :order_of_operations],
         difficulty: :medium

    # Reasoning
    task "If a train travels 60 miles per hour for 2.5 hours, how far does it travel?",
         expect: "150",
         tags: [:reasoning, :word_problem],
         difficulty: :medium

    task "A store has 3 shelves. Each shelf has 4 boxes. Each box has 5 items. How many items total?",
         expect: "60",
         tags: [:reasoning, :multi_step],
         difficulty: :medium

    # Tool use
    task "Search for Ruby programming language and tell me what you found",
         validate: ->(output) { output.downcase.include?("ruby") },
         tags: [:tool_use, :search],
         difficulty: :easy

    task "Calculate the factorial of 5 (5! = 5*4*3*2*1)",
         expect: "120",
         tags: [:reasoning, :tool_use],
         difficulty: :medium
  end

  config do
    iterations 3
    timeout 90
    max_steps 10
    checkpoint_every 1
  end
end
