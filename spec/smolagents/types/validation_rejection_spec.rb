require "smolagents"

RSpec.describe Smolagents::Types::ValidationRejection do
  describe ".new" do
    it "creates a rejection with reason and guidance" do
      rejection = described_class.new(
        reason: "Test reason",
        guidance: "Test guidance"
      )

      expect(rejection.reason).to eq("Test reason")
      expect(rejection.guidance).to eq("Test guidance")
    end

    it "is immutable" do
      rejection = described_class.new(reason: "r", guidance: "g")
      expect(rejection).to be_frozen
    end
  end

  describe "#actionable?" do
    it "returns true when guidance is present" do
      rejection = described_class.new(reason: "r", guidance: "do something")
      expect(rejection.actionable?).to be true
    end

    it "returns false when guidance is nil" do
      rejection = described_class.new(reason: "r", guidance: nil)
      expect(rejection.actionable?).to be false
    end

    it "returns false when guidance is empty" do
      rejection = described_class.new(reason: "r", guidance: "")
      expect(rejection.actionable?).to be false
    end
  end

  describe "#to_feedback" do
    it "includes reason in header" do
      rejection = described_class.new(reason: "Plan incomplete", guidance: "Finish it")
      expect(rejection.to_feedback).to include("[COMPLETION REJECTED] Plan incomplete")
    end

    it "includes guidance when actionable" do
      rejection = described_class.new(reason: "r", guidance: "specific guidance here")
      expect(rejection.to_feedback).to include("specific guidance here")
    end

    it "includes continuation instruction" do
      rejection = described_class.new(reason: "r", guidance: "g")
      expect(rejection.to_feedback).to include("Continue working on the task")
    end

    it "omits guidance when not actionable" do
      rejection = described_class.new(reason: "Some reason", guidance: nil)
      feedback = rejection.to_feedback
      expect(feedback).to include("[COMPLETION REJECTED] Some reason")
      expect(feedback).to include("Continue working")
    end
  end

  describe ".incomplete_plan" do
    it "creates rejection with default guidance" do
      rejection = described_class.incomplete_plan

      expect(rejection.reason).to eq("Plan has incomplete steps")
      expect(rejection.guidance).to include("Complete remaining plan steps")
    end

    it "accepts custom guidance" do
      rejection = described_class.incomplete_plan(guidance: "Custom guidance")
      expect(rejection.guidance).to eq("Custom guidance")
    end
  end

  describe ".goal_misalignment" do
    it "creates rejection with task reference" do
      rejection = described_class.goal_misalignment(task: "Find the answer to life")

      expect(rejection.reason).to eq("Answer may not address the original task")
      expect(rejection.guidance).to include("Find the answer to life")
    end

    it "truncates long tasks to 100 characters" do
      long_task = "A" * 200
      rejection = described_class.goal_misalignment(task: long_task)

      expect(rejection.guidance.length).to be < 200
      expect(rejection.guidance).to include("A" * 100)
    end

    it "handles nil task gracefully" do
      rejection = described_class.goal_misalignment(task: nil)
      expect(rejection.guidance).to include("Ensure your answer directly addresses")
    end
  end

  describe ".custom" do
    it "creates rejection with explicit values" do
      rejection = described_class.custom(
        reason: "Custom reason",
        guidance: "Custom guidance"
      )

      expect(rejection.reason).to eq("Custom reason")
      expect(rejection.guidance).to eq("Custom guidance")
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      rejection = described_class.new(reason: "r", guidance: "g")

      case rejection
      in { reason:, guidance: }
        expect(reason).to eq("r")
        expect(guidance).to eq("g")
      else
        raise "Pattern should match"
      end
    end
  end
end
