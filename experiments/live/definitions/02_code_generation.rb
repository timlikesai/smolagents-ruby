# Experiment: Code Generation
#
# Test models on code writing and debugging tasks.

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:code_generation) do
  description "Test code generation, debugging, and explanation capabilities"

  models do
    use :coder, :coder_model      # Devstral - coding specialist
    use :reasoning, :reasoning_model  # Qwen3-Coder-30B
    use :fast, :fast_model        # Fast baseline
  end

  tools do
    mock :run_ruby, "Execute Ruby code and return the result", code: String do |code:|
      # Simulated execution - don't actually run code
      # Just acknowledge the code and provide plausible output
      lines = code.strip.lines.size
      has_def = code.include?("def ")
      has_puts = code.include?("puts") || code.include?("print")

      response = "Code received (#{lines} lines):\n```ruby\n#{code[0..200]}#{"..." if code.length > 200}\n```\n\n"

      if has_def
        response += "Function defined successfully.\n"
      end

      if has_puts
        response += "Output would be printed.\n"
      end

      # Check for common patterns and provide expected results
      if code.include?("fibonacci") || code.include?("fib")
        response += "Fibonacci sequence output: 1, 1, 2, 3, 5"
      elsif code.include?("reverse")
        response += "Reversed 'hello': olleh"
      elsif code.include?("prime")
        response += "Prime check function ready."
      elsif code.include?("factorial")
        response += "Factorial of 5: 120"
      else
        response += "Execution simulated successfully."
      end

      response
    end

    mock :explain_code, "Explain what a piece of code does", code: String do |code:|
      "Code to analyze:\n```ruby\n#{code}\n```\n\nPlease provide your analysis."
    end
  end

  tasks do
    # Simple code generation
    task "Write a Ruby function that returns the sum of all numbers from 1 to n",
         validate: ->(output) { output.include?("def") && (output.include?("sum") || output.include?("+")) },
         tags: [:code_gen, :function],
         difficulty: :easy

    task "Write Ruby code to check if a number is prime",
         validate: ->(output) { output.include?("def") && output.include?("prime") },
         tags: [:code_gen, :algorithm],
         difficulty: :medium

    # Code execution
    task "Write and run Ruby code that prints the first 5 Fibonacci numbers",
         validate: ->(output) { output.include?("1") && output.include?("2") && output.include?("3") && output.include?("5") },
         tags: [:code_gen, :execution],
         difficulty: :medium

    task "Write Ruby code to reverse a string without using the reverse method, then test it with 'hello'",
         validate: ->(output) { output.include?("olleh") },
         tags: [:code_gen, :algorithm, :execution],
         difficulty: :medium

    # Debugging
    task "This Ruby code has a bug. Find and fix it:\n\ndef factorial(n)\n  return 1 if n == 0\n  n * factorial(n)\nend\n\nThe issue is infinite recursion.",
         validate: ->(output) { output.include?("n - 1") || output.include?("n-1") },
         tags: [:debugging],
         difficulty: :medium

    # Code explanation
    task "Explain what this Ruby code does:\n\ndef mystery(arr)\n  arr.each_with_object(Hash.new(0)) { |e, h| h[e] += 1 }\nend",
         validate: ->(output) { output.downcase.include?("count") || output.downcase.include?("frequency") || output.downcase.include?("hash") },
         tags: [:explanation],
         difficulty: :easy
  end

  config do
    iterations 2
    timeout 120
    max_steps 15
    checkpoint_every 1
  end
end
