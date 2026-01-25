require "smolagents"

RSpec.describe Smolagents::Types::ExecutionFeedback do
  describe "EXECUTION_ERROR_CATEGORIES" do
    it "defines all error categories" do
      categories = Smolagents::Types::EXECUTION_ERROR_CATEGORIES
      expect(categories).to include(:success, :syntax_error, :name_error, :tool_error, :timeout)
      expect(categories).to be_frozen
    end
  end

  describe ".success" do
    it "creates success feedback" do
      feedback = described_class.success(output: "result")

      expect(feedback.category).to eq(:success)
      expect(feedback.success?).to be true
      expect(feedback.failure?).to be false
      expect(feedback.message).to eq("result")
      expect(feedback.confidence).to eq(1.0)
    end

    it "handles nil output" do
      feedback = described_class.success
      expect(feedback.message).to eq("")
    end
  end

  describe ".failure" do
    it "creates failure feedback with all fields" do
      feedback = described_class.failure(
        category: :name_error,
        message: "undefined variable 'foo'",
        suggestion: "Define foo before using it",
        location: { line: 5, column: 10 },
        details: { variable: "foo" },
        confidence: 0.85
      )

      expect(feedback.category).to eq(:name_error)
      expect(feedback.message).to eq("undefined variable 'foo'")
      expect(feedback.suggestion).to eq("Define foo before using it")
      expect(feedback.location).to eq({ line: 5, column: 10 })
      expect(feedback.details).to eq({ variable: "foo" })
      expect(feedback.confidence).to eq(0.85)
    end

    it "uses default confidence of 0.7" do
      feedback = described_class.failure(
        category: :runtime_error,
        message: "error",
        suggestion: "fix it"
      )
      expect(feedback.confidence).to eq(0.7)
    end
  end

  describe ".syntax_error" do
    it "creates syntax error feedback" do
      feedback = described_class.syntax_error(
        message: "unexpected end of input",
        suggestion: "Add missing 'end' keyword",
        location: { line: 10 }
      )

      expect(feedback.category).to eq(:syntax_error)
      expect(feedback.syntax_fixable?).to be true
      expect(feedback.confidence).to eq(0.9)
    end
  end

  describe ".timeout" do
    it "creates timeout feedback with default message" do
      feedback = described_class.timeout
      expect(feedback.category).to eq(:timeout)
      expect(feedback.message).to eq("Execution timed out")
      expect(feedback.needs_new_approach?).to be true
    end

    it "accepts custom message" do
      feedback = described_class.timeout(message: "Took too long")
      expect(feedback.message).to eq("Took too long")
    end
  end

  describe "#success?" do
    it "returns true for success category" do
      feedback = described_class.success
      expect(feedback.success?).to be true
    end

    it "returns false for other categories" do
      feedback = described_class.failure(category: :name_error, message: "x", suggestion: "y")
      expect(feedback.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns false for success" do
      feedback = described_class.success
      expect(feedback.failure?).to be false
    end

    it "returns true for any error category" do
      feedback = described_class.failure(category: :type_error, message: "x", suggestion: "y")
      expect(feedback.failure?).to be true
    end
  end

  describe "#actionable?" do
    it "returns true when failure has suggestion" do
      feedback = described_class.failure(
        category: :name_error,
        message: "error",
        suggestion: "do this"
      )
      expect(feedback.actionable?).to be true
    end

    it "returns false for success" do
      feedback = described_class.success
      expect(feedback.actionable?).to be false
    end

    it "returns false when suggestion is nil" do
      feedback = described_class.new(
        category: :runtime_error,
        message: "error",
        suggestion: nil,
        location: nil,
        details: {},
        confidence: 0.5
      )
      expect(feedback.actionable?).to be false
    end

    it "returns false when suggestion is empty" do
      feedback = described_class.failure(
        category: :runtime_error,
        message: "error",
        suggestion: ""
      )
      expect(feedback.actionable?).to be false
    end
  end

  describe "#syntax_fixable?" do
    it "returns true for syntax errors" do
      feedback = described_class.syntax_error(message: "x", suggestion: "y")
      expect(feedback.syntax_fixable?).to be true
    end

    it "returns false for other errors" do
      feedback = described_class.failure(category: :name_error, message: "x", suggestion: "y")
      expect(feedback.syntax_fixable?).to be false
    end
  end

  describe "#needs_new_approach?" do
    it "returns true for tool errors" do
      feedback = described_class.failure(category: :tool_error, message: "x", suggestion: "y")
      expect(feedback.needs_new_approach?).to be true
    end

    it "returns true for timeout" do
      feedback = described_class.timeout
      expect(feedback.needs_new_approach?).to be true
    end

    it "returns true for memory limit" do
      feedback = described_class.failure(category: :memory_limit, message: "x", suggestion: "y")
      expect(feedback.needs_new_approach?).to be true
    end

    it "returns true for operation limit" do
      feedback = described_class.failure(category: :operation_limit, message: "x", suggestion: "y")
      expect(feedback.needs_new_approach?).to be true
    end

    it "returns false for fixable errors" do
      feedback = described_class.failure(category: :syntax_error, message: "x", suggestion: "y")
      expect(feedback.needs_new_approach?).to be false
    end
  end

  describe "#to_observation" do
    it "returns success message for success" do
      feedback = described_class.success
      expect(feedback.to_observation).to eq("Execution successful.")
    end

    it "includes category and message for failures" do
      feedback = described_class.failure(
        category: :name_error,
        message: "undefined local variable 'x'",
        suggestion: "Define x first"
      )
      observation = feedback.to_observation

      expect(observation).to include("Error [name_error]:")
      expect(observation).to include("undefined local variable 'x'")
      expect(observation).to include("Fix: Define x first")
    end

    it "includes location when present" do
      feedback = described_class.failure(
        category: :syntax_error,
        message: "unexpected token",
        suggestion: "fix it",
        location: { line: 42 }
      )
      expect(feedback.to_observation).to include("Location: line 42")
    end

    it "omits location when nil" do
      feedback = described_class.failure(
        category: :runtime_error,
        message: "error",
        suggestion: "fix"
      )
      expect(feedback.to_observation).not_to include("Location")
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      feedback = described_class.failure(
        category: :type_error,
        message: "wrong type",
        suggestion: "use correct type"
      )

      case feedback
      in { category: :type_error, message:, suggestion: }
        expect(message).to eq("wrong type")
        expect(suggestion).to eq("use correct type")
      else
        raise "Pattern should match"
      end
    end
  end

  describe "immutability" do
    it "is frozen" do
      feedback = described_class.success
      expect(feedback).to be_frozen
    end
  end
end
