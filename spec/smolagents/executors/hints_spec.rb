require_relative "../../../lib/smolagents/executors/hints"

RSpec.describe Smolagents::Executors::Hints do
  describe "VARIABLE_PATTERN" do
    it "matches variable references with operators" do
      pattern = described_class::VARIABLE_PATTERN

      expect(pattern).to match("step1 + 10")
      expect(pattern).to match("result1 - 5")
      expect(pattern).to match("value * 2")
      expect(pattern).to match("total / 3")
    end

    it "does not match simple variables" do
      pattern = described_class::VARIABLE_PATTERN

      expect(pattern).not_to match("step1")
      expect(pattern).not_to match("result")
    end
  end

  describe "COMMON_VAR_NAMES" do
    it "contains expected variable names" do
      expected = %w[result result1 step1 first_result value answer]
      expected.each do |name|
        expect(described_class::COMMON_VAR_NAMES).to include(name)
      end
    end
  end

  describe ".extract_undefined_var" do
    it "extracts variable from NameError" do
      error = NameError.new("undefined local variable or method `foo'")
      var = described_class.extract_undefined_var(error)

      expect(var).to eq("foo")
    end

    it "handles multiple quote styles" do
      error1 = NameError.new("undefined local variable or method `bar'")
      error2 = NameError.new("undefined local variable or method 'bar'")

      expect(described_class.extract_undefined_var(error1)).to eq("bar")
      expect(described_class.extract_undefined_var(error2)).to eq("bar")
    end

    it "extracts from undefined method errors" do
      error = NameError.new("undefined method `x'")
      var = described_class.extract_undefined_var(error)

      # Only extracted if it's in COMMON_VAR_NAMES
      expect(var).to eq("x")
    end

    it "returns nil for unknown format" do
      error = NameError.new("something else went wrong")
      var = described_class.extract_undefined_var(error)

      expect(var).to be_nil
    end

    it "returns nil for non-NameError" do
      error = RuntimeError.new("undefined variable")
      # This won't match the regex, so it returns nil
      var = described_class.extract_undefined_var(error)

      expect(var).to be_nil
    end
  end

  describe ".build_variable_hint" do
    it "creates helpful hint for variable reference in string" do
      hint = described_class.build_variable_hint("step1", "step1 + 10")

      expect(hint).to include("Variable 'step1' is referenced as a string literal")
      expect(hint).to include("calculate(expression: \"step1 + 10\")")
      expect(hint).to include("Fix option 1")
      expect(hint).to include("Fix option 2")
    end

    it "shows string interpolation fix" do
      hint = described_class.build_variable_hint("result", "result * 2")

      # The hint shows interpolation syntax like: #{result}
      expect(hint).to include("\#{result}")
    end

    it "suggests direct arithmetic as alternative" do
      hint = described_class.build_variable_hint("value", "value + 100")

      expect(hint).to include("Use direct arithmetic")
    end

    it "hints ToolResult support" do
      hint = described_class.build_variable_hint("x", "x - 1")

      expect(hint).to include("ToolResult supports math")
    end
  end

  describe ".analyze_expression" do
    it "returns nil for non-NameError" do
      error = RuntimeError.new("something failed")
      hint = described_class.analyze_expression("expression", error)

      expect(hint).to be_nil
    end

    it "returns hint for any variable in the expression" do
      error = NameError.new("undefined local variable or method `unusual_var_xyz'")
      hint = described_class.analyze_expression("unusual_var_xyz + 10", error)

      # analyze_expression provides hints for any variable found in the expression
      expect(hint).not_to be_nil
      expect(hint).to include("unusual_var_xyz")
    end

    it "returns hint when variable matches pattern" do
      error = NameError.new("undefined local variable or method `step1'")
      hint = described_class.analyze_expression("step1 + 10", error)

      expect(hint).to be_a(String)
      expect(hint).to include("step1")
    end

    it "returns nil when variable not in expression" do
      error = NameError.new("undefined local variable or method `step1'")
      hint = described_class.analyze_expression("step2 + 10", error)

      # step1 is not in the expression, so no hint
      expect(hint).to be_nil
    end

    it "detects variable references in strings" do
      error = NameError.new("undefined local variable or method `result1'")
      hint = described_class.analyze_expression("result1 - 5", error)

      expect(hint).not_to be_nil
      expect(hint).to include("result1")
    end
  end

  describe ".with_expression_hints" do
    it "yields and returns result on success" do
      result = described_class.with_expression_hints("1 + 1") do
        42
      end

      expect(result).to eq(42)
    end

    it "re-raises non-NameError exceptions" do
      expect do
        described_class.with_expression_hints("expression") do
          raise "oops"
        end
      end.to raise_error("oops")
    end

    it "raises InterpreterError with hint for variable mistakes" do
      expect do
        described_class.with_expression_hints("step1 + 10") do
          raise NameError, "undefined local variable or method `step1'"
        end
      end.to raise_error(Smolagents::InterpreterError) { |e| e.message.include?("HINT") }
    end

    it "includes original error in message" do
      expect do
        described_class.with_expression_hints("step1 + 10") do
          raise NameError, "undefined local variable or method `step1'"
        end
      end.to raise_error(Smolagents::InterpreterError) { |e| e.message.include?("undefined local variable") }
    end

    it "re-raises NameError without hint when no hint applies" do
      expect do
        described_class.with_expression_hints("expression") do
          raise NameError, "undefined local variable or method `xyz'"
        end
      end.to raise_error(NameError)
    end
  end

  describe ".create_helpful_calculate_tool" do
    it "returns a proc" do
      tool = described_class.create_helpful_calculate_tool

      expect(tool).to be_a(Proc)
    end

    it "calculates numeric expressions" do
      tool = described_class.create_helpful_calculate_tool

      expect(tool.call(expression: "1 + 1")).to eq(2.0)
      expect(tool.call(expression: "10 * 5")).to eq(50.0)
      expect(tool.call(expression: "100 / 4")).to eq(25.0)
    end

    it "returns float result for numeric" do
      tool = described_class.create_helpful_calculate_tool

      result = tool.call(expression: "5")
      expect(result).to be_a(Float)
      expect(result).to eq(5.0)
    end

    it "returns non-numeric result as-is" do
      tool = described_class.create_helpful_calculate_tool

      result = tool.call(expression: '"hello"')
      expect(result).to eq("hello")
    end

    it "handles complex expressions" do
      tool = described_class.create_helpful_calculate_tool

      result = tool.call(expression: "(10 + 5) * 2")
      expect(result).to eq(30.0)
    end

    it "provides helpful error messages for undefined variables" do
      tool = described_class.create_helpful_calculate_tool

      expect do
        tool.call(expression: "step1 + 10")
      end.to raise_error(Smolagents::InterpreterError) { |e| e.message.include?("HINT") }
    end

    it "works as a tool in executor context" do
      tool = described_class.create_helpful_calculate_tool

      # Simulates tool call interface
      result = tool.call(expression: "2 ** 8")
      expect(result).to eq(256.0)
    end
  end

  describe "hint generation quality" do
    it "provides clear examples for common mistake" do
      error = NameError.new("undefined local variable or method `result'")
      hint = described_class.analyze_expression("result + 10", error)

      expect(hint).to include("You wrote:")
      expect(hint).to include("Fix option 1")
      expect(hint).to include("Fix option 2")
    end

    it "explains the problem clearly" do
      error = NameError.new("undefined local variable or method `value'")
      hint = described_class.analyze_expression("value * 2", error)

      expect(hint).to include("string literal")
      expect(hint).to include("doesn't exist")
    end

    it "provides interpolation syntax example" do
      error = NameError.new("undefined local variable or method `x'")
      hint = described_class.analyze_expression("x + 1", error)

      expect(hint).to match(/\#\{x\}/)
    end
  end

  describe "edge cases" do
    it "handles nil error gracefully" do
      # This shouldn't happen in practice
      hint = described_class.analyze_expression("x + 1", nil)

      expect(hint).to be_nil
    end

    it "handles empty expression" do
      error = NameError.new("undefined local variable or method `x'")
      hint = described_class.analyze_expression("", error)

      expect(hint).to be_nil
    end

    it "handles very long expressions" do
      long_expr = "step1 + #{"1 " * 1000}"
      error = NameError.new("undefined local variable or method `step1'")

      # Should still work
      hint = described_class.analyze_expression(long_expr, error)
      expect(hint).not_to be_nil
    end

    it "handles variable names with underscores" do
      error = NameError.new("undefined local variable or method `my_var_1'")
      # analyze_expression provides hints for any variable in the expression
      hint = described_class.analyze_expression("my_var_1 + 10", error)

      expect(hint).not_to be_nil
      expect(hint).to include("my_var_1")
    end

    it "handles common variables with underscores" do
      error = NameError.new("undefined local variable or method `first_result'")
      hint = described_class.analyze_expression("first_result + 10", error)

      # first_result IS in COMMON_VAR_NAMES, so hint should apply
      expect(hint).not_to be_nil
    end
  end
end
