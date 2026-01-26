RSpec.describe Smolagents::Types::CompletedStep do
  describe "attributes" do
    it "has step and outcome" do
      completed = described_class.new(step: 3, outcome: :success)

      expect(completed.step).to eq(3)
      expect(completed.outcome).to eq(:success)
    end
  end

  describe "#success?" do
    it "returns true when outcome is :success" do
      completed = described_class.new(step: 1, outcome: :success)

      expect(completed.success?).to be true
    end

    it "returns false for other outcomes" do
      %i[error final_answer failure].each do |outcome|
        completed = described_class.new(step: 1, outcome:)

        expect(completed.success?).to be false
      end
    end
  end

  describe "#final_answer?" do
    it "returns true when outcome is :final_answer" do
      completed = described_class.new(step: 5, outcome: :final_answer)

      expect(completed.final_answer?).to be true
    end

    it "returns false for other outcomes" do
      %i[success error failure].each do |outcome|
        completed = described_class.new(step: 1, outcome:)

        expect(completed.final_answer?).to be false
      end
    end
  end

  describe "#error?" do
    it "returns true when outcome is :error" do
      completed = described_class.new(step: 2, outcome: :error)

      expect(completed.error?).to be true
    end

    it "returns false for other outcomes" do
      %i[success final_answer failure].each do |outcome|
        completed = described_class.new(step: 1, outcome:)

        expect(completed.error?).to be false
      end
    end
  end

  describe "immutability" do
    it "is frozen" do
      completed = described_class.new(step: 1, outcome: :success)

      expect(completed).to be_frozen
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "matches on step" do
      completed = described_class.new(step: 3, outcome: :success)

      matched = case completed
                in step: 3
                  "step 3"
                else
                  "other"
                end

      expect(matched).to eq("step 3")
    end

    it "matches on outcome" do
      completed = described_class.new(step: 1, outcome: :final_answer)

      matched = case completed
                in outcome: :final_answer
                  "final"
                else
                  "other"
                end

      expect(matched).to eq("final")
    end

    it "matches both fields" do
      completed = described_class.new(step: 5, outcome: :success)

      matched = case completed
                in step: 5, outcome: :success
                  "exact match"
                else
                  "no match"
                end

      expect(matched).to eq("exact match")
    end
  end

  describe "serialization" do
    it "converts to hash" do
      completed = described_class.new(step: 2, outcome: :error)
      hash = completed.to_h

      expect(hash).to eq({ step: 2, outcome: :error })
    end
  end
end
