require "spec_helper"

RSpec.describe Smolagents::Types::ToolRecoveryResult do
  let(:recovery_action) { Smolagents::Types::RecoveryAction }

  describe ".success" do
    subject(:result) { described_class.success("data", attempts: 2) }

    it "sets action to RETRY by default" do
      expect(result.action).to eq(recovery_action::RETRY)
    end

    it "sets success to true" do
      expect(result.success).to be true
    end

    it "sets attempts" do
      expect(result.attempts).to eq(2)
    end

    it "sets final_result" do
      expect(result.final_result).to eq("data")
    end

    it "sets original_error to nil" do
      expect(result.original_error).to be_nil
    end

    it "sets reason for recovery" do
      expect(result.reason).to eq("Recovered after 2 attempts")
    end

    it "sets reason for immediate success" do
      single = described_class.success("data", attempts: 1)
      expect(single.reason).to eq("Success")
    end

    it "accepts custom action" do
      switched = described_class.success("data", attempts: 1, action: recovery_action::SWITCH)
      expect(switched.action).to eq(recovery_action::SWITCH)
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe ".failure" do
    subject(:result) { described_class.failure(error, attempts: 3) }

    let(:error) { RuntimeError.new("test error") }

    it "sets action to TERMINATE" do
      expect(result.action).to eq(recovery_action::TERMINATE)
    end

    it "sets success to false" do
      expect(result.success).to be false
    end

    it "sets attempts" do
      expect(result.attempts).to eq(3)
    end

    it "sets original_error" do
      expect(result.original_error).to eq(error)
    end

    it "sets final_result to nil" do
      expect(result.final_result).to be_nil
    end

    it "uses error message as reason by default" do
      expect(result.reason).to eq("test error")
    end

    it "accepts custom reason" do
      custom = described_class.failure(error, attempts: 1, reason: "Custom reason")
      expect(custom.reason).to eq("Custom reason")
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe "#success?" do
    it "returns true for successful result" do
      result = described_class.success("data")
      expect(result.success?).to be true
    end

    it "returns false for failed result" do
      result = described_class.failure(RuntimeError.new("fail"))
      expect(result.success?).to be false
    end
  end

  describe "#failed?" do
    it "returns false for successful result" do
      result = described_class.success("data")
      expect(result.failed?).to be false
    end

    it "returns true for failed result" do
      result = described_class.failure(RuntimeError.new("fail"))
      expect(result.failed?).to be true
    end
  end

  describe "#recovered?" do
    it "returns true when success and attempts > 1" do
      result = described_class.success("data", attempts: 2)
      expect(result.recovered?).to be true
    end

    it "returns false when success and attempts == 1" do
      result = described_class.success("data", attempts: 1)
      expect(result.recovered?).to be false
    end

    it "returns false for failed result even with multiple attempts" do
      result = described_class.failure(RuntimeError.new("fail"), attempts: 3)
      expect(result.recovered?).to be false
    end
  end

  describe "#gave_up?" do
    it "returns true when action is TERMINATE" do
      result = described_class.failure(RuntimeError.new("fail"))
      expect(result.gave_up?).to be true
    end

    it "returns false when action is RETRY" do
      result = described_class.success("data")
      expect(result.gave_up?).to be false
    end

    it "returns false when action is SWITCH" do
      result = described_class.success("data", action: recovery_action::SWITCH)
      expect(result.gave_up?).to be false
    end
  end

  describe "immutability" do
    it "is frozen on creation via factory" do
      result = described_class.success("data")
      expect(result).to be_frozen
    end

    it "is frozen via direct creation" do
      result = described_class.new(
        action: recovery_action::RETRY,
        success: true,
        attempts: 1,
        original_error: nil,
        final_result: "test",
        reason: "Success"
      )
      expect(result).to be_frozen
    end
  end
end
