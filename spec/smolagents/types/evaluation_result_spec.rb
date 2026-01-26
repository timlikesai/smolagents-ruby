require "smolagents"

RSpec.describe Smolagents::Types::EvaluationResult do
  describe ".achieved" do
    it "creates goal_achieved result" do
      result = described_class.achieved(answer: "42")
      expect(result.goal_achieved?).to be(true)
      expect(result.answer).to eq("42")
    end

    it "uses default high confidence" do
      result = described_class.achieved(answer: "42")
      expect(result.confidence).to eq(Smolagents::Types::DEFAULT_CONFIDENCE[:goal_achieved])
    end

    it "accepts custom confidence" do
      result = described_class.achieved(answer: "42", confidence: 0.75)
      expect(result.confidence).to eq(0.75)
    end

    it "accepts token_usage" do
      usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      result = described_class.achieved(answer: "42", token_usage: usage)
      expect(result.token_usage).to eq(usage)
    end
  end

  describe ".continue" do
    it "creates continue result" do
      result = described_class.continue(reasoning: "need more data")
      expect(result.continue?).to be(true)
      expect(result.reasoning).to eq("need more data")
    end

    it "uses default medium confidence" do
      result = described_class.continue
      expect(result.confidence).to eq(Smolagents::Types::DEFAULT_CONFIDENCE[:continue])
    end

    it "accepts custom confidence" do
      result = described_class.continue(reasoning: "test", confidence: 0.4)
      expect(result.confidence).to eq(0.4)
    end
  end

  describe ".stuck" do
    it "creates stuck result" do
      result = described_class.stuck(reasoning: "tool unavailable")
      expect(result.stuck?).to be(true)
      expect(result.reasoning).to eq("tool unavailable")
    end

    it "uses default low confidence" do
      result = described_class.stuck(reasoning: "blocked")
      expect(result.confidence).to eq(Smolagents::Types::DEFAULT_CONFIDENCE[:stuck])
    end

    it "accepts custom confidence" do
      result = described_class.stuck(reasoning: "blocked", confidence: 0.1)
      expect(result.confidence).to eq(0.1)
    end
  end

  describe "#confident?" do
    it "returns true when confidence >= threshold" do
      result = described_class.achieved(answer: "x", confidence: 0.8)
      expect(result.confident?(threshold: 0.7)).to be(true)
    end

    it "returns false when confidence < threshold" do
      result = described_class.continue(confidence: 0.5)
      expect(result.confident?(threshold: 0.7)).to be(false)
    end

    it "handles nil confidence" do
      result = described_class.new(
        status: :continue, answer: nil, reasoning: nil, confidence: nil, token_usage: nil
      )
      expect(result.confident?).to be(false)
    end

    it "uses 0.7 as default threshold" do
      high = described_class.achieved(answer: "x", confidence: 0.75)
      low = described_class.continue(confidence: 0.65)
      expect(high.confident?).to be(true)
      expect(low.confident?).to be(false)
    end
  end

  describe "#low_confidence?" do
    it "returns true when confidence < threshold" do
      result = described_class.stuck(reasoning: "x", confidence: 0.2)
      expect(result.low_confidence?(threshold: 0.4)).to be(true)
    end

    it "returns false when confidence >= threshold" do
      result = described_class.continue(confidence: 0.5)
      expect(result.low_confidence?(threshold: 0.4)).to be(false)
    end

    it "handles nil confidence" do
      result = described_class.new(
        status: :continue, answer: nil, reasoning: nil, confidence: nil, token_usage: nil
      )
      expect(result.low_confidence?).to be(true)
    end

    it "uses 0.4 as default threshold" do
      low = described_class.stuck(reasoning: "x", confidence: 0.35)
      ok = described_class.continue(confidence: 0.45)
      expect(low.low_confidence?).to be(true)
      expect(ok.low_confidence?).to be(false)
    end
  end

  describe "status predicates" do
    it "returns correct boolean for goal_achieved?" do
      achieved = described_class.achieved(answer: "x")
      continue = described_class.continue
      stuck = described_class.stuck(reasoning: "x")

      expect(achieved.goal_achieved?).to be(true)
      expect(continue.goal_achieved?).to be(false)
      expect(stuck.goal_achieved?).to be(false)
    end

    it "returns correct boolean for continue?" do
      achieved = described_class.achieved(answer: "x")
      continue = described_class.continue
      stuck = described_class.stuck(reasoning: "x")

      expect(achieved.continue?).to be(false)
      expect(continue.continue?).to be(true)
      expect(stuck.continue?).to be(false)
    end

    it "returns correct boolean for stuck?" do
      achieved = described_class.achieved(answer: "x")
      continue = described_class.continue
      stuck = described_class.stuck(reasoning: "x")

      expect(achieved.stuck?).to be(false)
      expect(continue.stuck?).to be(false)
      expect(stuck.stuck?).to be(true)
    end
  end
end
