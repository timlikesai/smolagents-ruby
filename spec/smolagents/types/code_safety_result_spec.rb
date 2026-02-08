require "smolagents"

RSpec.describe Smolagents::Types::CodeSafetyResult do
  let(:safe_result) { described_class.safe }
  let(:rejected_result) { described_class.rejected("Unbounded allocation detected") }

  it_behaves_like "a frozen type" do
    let(:instance) { safe_result }
  end

  it_behaves_like "a pattern matchable type" do
    let(:instance) { safe_result }
  end

  describe ".safe" do
    it "creates a safe result with nil reason" do
      result = described_class.safe
      expect(result.outcome).to eq(:safe)
      expect(result.reason).to be_nil
    end
  end

  describe ".rejected" do
    it "creates a rejected result with reason" do
      result = described_class.rejected("unsafe code detected")
      expect(result.outcome).to eq(:rejected)
      expect(result.reason).to eq("unsafe code detected")
    end
  end

  describe "#safe?" do
    it "returns true for safe results" do
      expect(safe_result.safe?).to be true
    end

    it "returns false for rejected results" do
      expect(rejected_result.safe?).to be false
    end
  end

  describe "#rejected?" do
    it "returns true for rejected results" do
      expect(rejected_result.rejected?).to be true
    end

    it "returns false for safe results" do
      expect(safe_result.rejected?).to be false
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash with outcome and reason" do
      result = safe_result.deconstruct_keys(nil)
      expect(result).to eq({ outcome: :safe, reason: nil })
    end

    it "includes reason for rejected results" do
      result = rejected_result.deconstruct_keys(nil)
      expect(result).to eq({ outcome: :rejected, reason: "Unbounded allocation detected" })
    end
  end

  describe "pattern matching" do
    it "matches on outcome" do
      matched = case safe_result
                in { outcome: :safe }
                  "safe"
                else
                  "other"
                end

      expect(matched).to eq("safe")
    end

    it "matches rejected with reason" do
      matched = case rejected_result
                in { outcome: :rejected, reason: r }
                  r
                else
                  "no match"
                end

      expect(matched).to eq("Unbounded allocation detected")
    end

    it "supports conditional matching on reason" do
      matched = case rejected_result
                in { reason: /allocation/i } then "allocation issue"
                in { reason: /unsafe/ } then "unsafe issue"
                else "other"
                end

      expect(matched).to eq("allocation issue")
    end
  end
end
