require "smolagents"

RSpec.describe Smolagents::Concerns::ExecutionOracle do
  let(:oracle_class) do
    Class.new do
      include Smolagents::Concerns::ExecutionOracle
    end
  end

  let(:oracle) { oracle_class.new }

  describe Smolagents::Concerns::ExecutionOracle::ExecutionFeedback do
    describe ".success" do
      it "creates success feedback" do
        feedback = described_class.success(output: "42")
        expect(feedback.success?).to be(true)
        expect(feedback.failure?).to be(false)
        expect(feedback.category).to eq(:success)
      end
    end

    describe ".failure" do
      it "creates failure feedback" do
        feedback = described_class.failure(
          category: :syntax_error,
          message: "unexpected end",
          suggestion: "Add missing 'end'",
          confidence: 0.9
        )
        expect(feedback.failure?).to be(true)
        expect(feedback.success?).to be(false)
        expect(feedback.actionable?).to be(true)
      end
    end

    describe "#syntax_fixable?" do
      it "returns true for syntax errors" do
        feedback = described_class.failure(
          category: :syntax_error,
          message: "syntax error",
          suggestion: "fix it"
        )
        expect(feedback.syntax_fixable?).to be(true)
      end

      it "returns false for other errors" do
        feedback = described_class.failure(
          category: :name_error,
          message: "undefined foo",
          suggestion: "fix it"
        )
        expect(feedback.syntax_fixable?).to be(false)
      end
    end

    describe "#needs_new_approach?" do
      it "returns true for tool errors" do
        feedback = described_class.failure(
          category: :tool_error,
          message: "tool failed",
          suggestion: "try another"
        )
        expect(feedback.needs_new_approach?).to be(true)
      end

      it "returns true for timeout" do
        feedback = described_class.failure(
          category: :timeout,
          message: "timed out",
          suggestion: "simplify"
        )
        expect(feedback.needs_new_approach?).to be(true)
      end

      it "returns false for syntax errors" do
        feedback = described_class.failure(
          category: :syntax_error,
          message: "syntax error",
          suggestion: "fix it"
        )
        expect(feedback.needs_new_approach?).to be(false)
      end
    end

    describe "#to_observation" do
      it "formats success feedback" do
        feedback = described_class.success
        expect(feedback.to_observation).to eq("Execution successful.")
      end

      it "formats failure feedback with all parts" do
        feedback = described_class.failure(
          category: :syntax_error,
          message: "unexpected end",
          suggestion: "Add missing keyword",
          location: { line: 5 }
        )
        observation = feedback.to_observation
        expect(observation).to include("Error [syntax_error]")
        expect(observation).to include("unexpected end")
        expect(observation).to include("Location: line 5")
        expect(observation).to include("Fix: Add missing keyword")
      end
    end
  end

  describe "#analyze_execution" do
    let(:success_result) do
      Smolagents::Executors::Executor::ExecutionResult.success(output: "42", logs: "")
    end

    let(:failure_result) do
      Smolagents::Executors::Executor::ExecutionResult.failure(error: "undefined local variable or method `foo'",
                                                               logs: "")
    end

    it "returns success feedback for successful execution" do
      feedback = oracle.analyze_execution(success_result)
      expect(feedback.success?).to be(true)
      expect(feedback.details[:output]).to eq("42")
    end

    it "returns failure feedback for failed execution" do
      feedback = oracle.analyze_execution(failure_result)
      expect(feedback.failure?).to be(true)
      expect(feedback.category).to eq(:name_error)
    end

    it "includes actionable suggestion" do
      feedback = oracle.analyze_execution(failure_result)
      expect(feedback.actionable?).to be(true)
      expect(feedback.suggestion).not_to be_empty
    end
  end

  describe "#classify_error" do
    it "classifies syntax errors" do
      category = oracle.classify_error("syntax error, unexpected end-of-input")
      expect(category).to eq(:syntax_error)
    end

    it "classifies name errors" do
      category = oracle.classify_error("undefined local variable or method `foo'")
      expect(category).to eq(:name_error)
    end

    it "classifies no method errors" do
      category = oracle.classify_error("undefined method `bar' for an instance of String")
      expect(category).to eq(:no_method_error)
    end

    it "classifies type errors" do
      category = oracle.classify_error("no implicit conversion of Integer into String")
      expect(category).to eq(:type_error)
    end

    it "classifies argument errors" do
      category = oracle.classify_error("wrong number of arguments (given 2, expected 1)")
      expect(category).to eq(:argument_error)
    end

    it "classifies tool errors" do
      category = oracle.classify_error("Tool `missing_tool' not found")
      expect(category).to eq(:tool_error)
    end

    it "classifies timeout errors" do
      category = oracle.classify_error("execution timed out after 30s")
      expect(category).to eq(:timeout)
    end

    it "classifies memory limit errors" do
      category = oracle.classify_error("memory limit exceeded")
      expect(category).to eq(:memory_limit)
    end

    it "classifies operation limit errors" do
      category = oracle.classify_error("operation limit exceeded: too many operations")
      expect(category).to eq(:operation_limit)
    end

    it "defaults to runtime_error for unknown errors" do
      category = oracle.classify_error("something went wrong")
      expect(category).to eq(:runtime_error)
    end
  end

  describe "error parsing" do
    describe "name errors" do
      it "extracts undefined variable name" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "undefined local variable or method `my_var'",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:undefined_name]).to eq("my_var")
      end

      it "suggests similar names from code" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "undefined local variable or method `my_vr'",
          logs: ""
        )
        code = "my_var = 10\nresult = my_vr + 5"
        feedback = oracle.analyze_execution(result, code)
        expect(feedback.suggestion).to include("my_var")
      end
    end

    describe "no method errors" do
      it "extracts method and receiver" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "undefined method `foo' for an instance of String",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:undefined_method]).to eq("foo")
        expect(feedback.details[:receiver_class]).to eq("String")
      end

      it "generates helpful suggestion" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "undefined method `foo' for an instance of Array",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.suggestion).to include("Array")
        expect(feedback.suggestion).to include("foo")
      end
    end

    describe "type errors" do
      it "extracts type conversion info" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "no implicit conversion of Integer into String",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:from_type]).to eq("Integer")
        expect(feedback.details[:to_type]).to eq("String")
      end

      it "suggests explicit conversion" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "no implicit conversion of Integer into String",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.suggestion).to include("Convert")
        expect(feedback.suggestion).to include(".to_s")
      end
    end

    describe "argument errors" do
      it "extracts given and expected counts" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "wrong number of arguments (given 3, expected 1)",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:given]).to eq(3)
        expect(feedback.details[:expected]).to eq("1")
      end

      it "suggests correct argument count" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "wrong number of arguments (given 3, expected 1)",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.suggestion).to include("1")
        expect(feedback.suggestion).to include("3")
      end
    end

    describe "syntax errors" do
      it "extracts unexpected token" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "syntax error, unexpected end-of-input",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:unexpected]).to eq("end-of-input")
      end

      it "provides syntax fix suggestion" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "syntax error, unexpected end-of-input, expecting end",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.suggestion).to include("end")
      end
    end

    describe "tool errors" do
      it "extracts tool name" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "Tool `search_web' not found",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.details[:tool_name]).to eq("search_web")
      end

      it "suggests using different tool" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(
          error: "Tool `missing' not found",
          logs: ""
        )
        feedback = oracle.analyze_execution(result)
        expect(feedback.suggestion).to include("not available")
      end
    end
  end

  describe "confidence calculation" do
    it "has high confidence for well-parsed syntax errors" do
      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "syntax error, unexpected end",
        logs: ""
      )
      feedback = oracle.analyze_execution(result)
      expect(feedback.confidence).to be >= 0.7
    end

    it "has high confidence for tool errors with name" do
      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "Tool `foo' not found",
        logs: ""
      )
      feedback = oracle.analyze_execution(result)
      expect(feedback.confidence).to be >= 0.9
    end

    it "has lower confidence for generic runtime errors" do
      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "something unexpected happened",
        logs: ""
      )
      feedback = oracle.analyze_execution(result)
      expect(feedback.confidence).to be <= 0.6
    end
  end

  describe "pattern matching support" do
    it "supports pattern matching on category" do
      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "undefined local variable or method `x'",
        logs: ""
      )
      feedback = oracle.analyze_execution(result)

      matched = case feedback
                in Smolagents::Concerns::ExecutionOracle::ExecutionFeedback[category: :name_error]
                  true
                else
                  false
                end

      expect(matched).to be(true)
    end

    it "supports pattern matching with details extraction" do
      result = Smolagents::Executors::Executor::ExecutionResult.failure(
        error: "undefined local variable or method `my_variable'",
        logs: ""
      )
      feedback = oracle.analyze_execution(result)

      name = case feedback
             in Smolagents::Concerns::ExecutionOracle::ExecutionFeedback[details: { undefined_name: n }]
               n
             end

      expect(name).to eq("my_variable")
    end
  end
end
