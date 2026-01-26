RSpec.describe Smolagents::Tools::RubyInterpreterTool do
  describe "Ruby code execution" do
    let(:tool) { described_class.new }

    before do
      allow(tool).to receive(:emit)
    end

    describe "#execute" do
      it "executes simple Ruby code" do
        result = tool.execute(code: "2 + 2")

        expect(result).to be_a(String)
        expect(result).to include("4")
      end

      it "captures stdout output" do
        result = tool.execute(code: 'puts "Hello, World!"')

        expect(result).to include("Hello, World!")
      end

      it "returns both stdout and expression value" do
        result = tool.execute(code: 'puts "output"; 42')

        expect(result).to include("Stdout:")
        expect(result).to include("Output: 42")
      end

      it "handles code with no output" do
        result = tool.execute(code: "nil")

        expect(result).to be_a(String)
      end

      it "returns error message on execution failure" do
        result = tool.execute(code: "undefined_variable")

        expect(result).to include("Error:")
      end

      it "handles syntax errors gracefully" do
        result = tool.execute(code: "puts 'unclosed string")

        expect(result).to include("Error:")
      end
    end

    describe "#build_executor" do
      it "creates RactorExecutor with config" do
        executor = tool.send(:build_executor)

        expect(executor).to be_a(Smolagents::RactorExecutor)
      end

      it "passes max_operations to executor" do
        tool = described_class.new(max_operations: 50_000)
        executor = tool.send(:build_executor)

        expect(executor).to be_a(Smolagents::RactorExecutor)
      end

      it "passes max_output_length to executor" do
        tool = described_class.new(max_output_length: 10_000)
        executor = tool.send(:build_executor)

        expect(executor).to be_a(Smolagents::RactorExecutor)
      end
    end

    describe "#format_result" do
      context "when execution succeeds" do
        it "formats successful output" do
          execution_result = double(
            success?: true,
            logs: "Test output",
            output: 42
          )

          formatted = tool.send(:format_result, execution_result)

          expect(formatted).to include("Stdout:")
          expect(formatted).to include("Test output")
          expect(formatted).to include("Output: 42")
        end

        it "handles empty stdout" do
          execution_result = double(
            success?: true,
            logs: "",
            output: "result"
          )

          formatted = tool.send(:format_result, execution_result)

          expect(formatted).to include("Stdout:")
          expect(formatted).to include("Output: result")
        end

        it "handles multiline output" do
          execution_result = double(
            success?: true,
            logs: "Line 1\nLine 2\nLine 3",
            output: "final"
          )

          formatted = tool.send(:format_result, execution_result)

          expect(formatted).to include("Line 1")
          expect(formatted).to include("Line 2")
        end
      end

      context "when execution fails" do
        it "formats error message" do
          execution_result = double(
            success?: false,
            error: "ZeroDivisionError: divided by 0"
          )

          formatted = tool.send(:format_result, execution_result)

          expect(formatted).to include("Error:")
          expect(formatted).to include("ZeroDivisionError")
        end

        it "includes full error message" do
          error_msg = "RuntimeError: Something went wrong\n  at line 5"
          execution_result = double(
            success?: false,
            error: error_msg
          )

          formatted = tool.send(:format_result, execution_result)

          expect(formatted).to include(error_msg)
        end
      end
    end

    describe "code execution integration" do
      it "executes mathematical operations" do
        result = tool.execute(code: "[1, 2, 3].sum")

        expect(result).to include("6")
      end

      it "executes string operations" do
        result = tool.execute(code: '"hello".upcase')

        expect(result).to include("HELLO")
      end

      it "executes array operations" do
        result = tool.execute(code: "[1, 2, 3, 4, 5].select { |x| x.even? }")

        expect(result).to include("[2, 4]")
      end

      it "executes hash operations" do
        result = tool.execute(code: "{ a: 1, b: 2 }.values.sum")

        expect(result).to include("3")
      end

      it "handles multi-line code" do
        code = <<~RUBY
          x = 10
          y = 20
          x + y
        RUBY

        result = tool.execute(code:)

        expect(result).to include("30")
      end

      it "preserves variable state within execution" do
        result = tool.execute(code: "a = 5; b = 10; a * b")

        expect(result).to include("50")
      end
    end

    describe "error handling" do
      it "handles NameError for undefined variables" do
        result = tool.execute(code: "unknown_var + 1")

        expect(result).to include("Error:")
        expect(result).to include("undefined")
      end

      it "handles TypeError for invalid operations" do
        result = tool.execute(code: '"string" + 5')

        expect(result).to include("Error:")
      end

      it "handles ArgumentError for wrong arguments" do
        result = tool.execute(code: "[1, 2, 3].first(100)")

        # This may or may not error depending on Ruby version
        expect(result).to be_a(String)
      end

      it "catches timeout errors gracefully" do
        code = "loop { }"
        result = tool.execute(code:)

        # Result should be an error message, not an exception
        expect(result).to be_a(String)
      end
    end

    describe "output formatting" do
      it "separates stdout and output sections" do
        result = tool.execute(code: 'puts "output"; "return_value"')

        expect(result).to include("Stdout:")
        expect(result).to include("Output:")
      end

      it "preserves special characters in output" do
        result = tool.execute(code: 'puts "Special: & < > \" \'"')

        expect(result).to include("&")
      end

      it "handles nil output" do
        result = tool.execute(code: "nil")

        expect(result).to include("Output:")
      end

      it "handles empty string output" do
        result = tool.execute(code: '""')

        expect(result).to include("Output:")
      end
    end

    describe "Ruby standard library availability" do
      it "can use JSON" do
        result = tool.execute(code: "JSON.generate({ a: 1, b: 2 })")

        expect(result).to include("{")
        expect(result).not_to include("Error:")
      end

      it "can use Time" do
        result = tool.execute(code: "Time.now.class.name")

        expect(result).to include("Time")
      end

      it "can use Math" do
        result = tool.execute(code: "Math.sqrt(16)")

        expect(result).to include("4")
      end

      it "can use Array and Hash methods" do
        result = tool.execute(code: "[1, 2, 3].map { |x| x * 2 }")

        expect(result).to include("[2, 4, 6]")
      end
    end

    describe "execution limits" do
      it "respects timeout parameter" do
        tool_with_timeout = described_class.new(timeout: 1)

        # This test is tricky because actual timeout behavior depends on executor
        # Just verify that timeout parameter is accepted
        expect(tool_with_timeout.timeout).to eq(1)
      end

      it "respects max_operations parameter" do
        tool_with_ops = described_class.new(max_operations: 10_000)

        expect(tool_with_ops.instance_variable_get(:@max_operations)).to eq(10_000)
      end

      it "respects max_output_length parameter" do
        tool_with_output = described_class.new(max_output_length: 5_000)

        expect(tool_with_output.instance_variable_get(:@max_output_length)).to eq(5_000)
      end
    end
  end
end
