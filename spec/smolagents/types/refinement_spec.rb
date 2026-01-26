RSpec.describe Smolagents::Types::RefineConfig do
  describe ".default" do
    it "creates config with default values" do
      config = described_class.default

      expect(config.max_iterations).to eq(3)
      expect(config.feedback_source).to eq(:execution)
      expect(config.min_confidence).to eq(0.8)
      expect(config.enabled).to be true
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".disabled" do
    it "creates config with refinement disabled" do
      config = described_class.disabled

      expect(config.max_iterations).to eq(0)
      expect(config.min_confidence).to eq(1.0)
      expect(config.enabled).to be false
    end

    it "is frozen" do
      config = described_class.disabled

      expect(config).to be_frozen
    end
  end

  describe "default values" do
    it "max_iterations defaults to 3" do
      expect(described_class.default.max_iterations).to eq(3)
    end

    it "feedback_source defaults to :execution" do
      expect(described_class.default.feedback_source).to eq(:execution)
    end
  end

  describe "attributes" do
    it "allows custom configuration" do
      config = described_class.new(
        max_iterations: 5,
        feedback_source: :self,
        min_confidence: 0.9,
        enabled: true
      )

      expect(config.max_iterations).to eq(5)
      expect(config.feedback_source).to eq(:self)
      expect(config.min_confidence).to eq(0.9)
    end
  end
end

RSpec.describe Smolagents::Types::RefinementResult do
  let(:feedback) do
    Smolagents::Types::RefinementFeedback.new(
      iteration: 1,
      source: :execution,
      critique: "Could be more specific",
      actionable: true,
      confidence: 0.8
    )
  end

  describe ".no_refinement_needed" do
    it "creates result with no iterations" do
      result = described_class.no_refinement_needed("response")

      expect(result.original).to eq("response")
      expect(result.refined).to eq("response")
      expect(result.iterations).to eq(0)
      expect(result.feedback_history).to be_empty
      expect(result.improved).to be false
    end

    it "accepts custom confidence" do
      result = described_class.no_refinement_needed("response", confidence: 0.95)

      expect(result.confidence).to eq(0.95)
    end

    it "is frozen" do
      result = described_class.no_refinement_needed("response")

      expect(result).to be_frozen
    end
  end

  describe ".after_refinement" do
    it "creates result after refinement cycles" do
      result = described_class.after_refinement(
        original: "first draft",
        refined: "improved draft",
        iterations: 2,
        feedback_history: [feedback],
        improved: true,
        confidence: 0.9
      )

      expect(result.original).to eq("first draft")
      expect(result.refined).to eq("improved draft")
      expect(result.iterations).to eq(2)
      expect(result.feedback_history).to eq([feedback])
      expect(result.improved).to be true
      expect(result.confidence).to eq(0.9)
    end
  end

  describe "#refined?" do
    it "returns true when iterations > 0" do
      result = described_class.after_refinement(
        original: "x",
        refined: "y",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9
      )

      expect(result.refined?).to be true
    end

    it "returns false when iterations == 0" do
      result = described_class.no_refinement_needed("x")

      expect(result.refined?).to be false
    end
  end

  describe "#maxed_out?" do
    it "returns true when iterations >= max" do
      result = described_class.after_refinement(
        original: "x",
        refined: "y",
        iterations: 3,
        feedback_history: [],
        improved: false,
        confidence: 0.5
      )

      expect(result.maxed_out?(3)).to be true
    end

    it "returns false when iterations < max" do
      result = described_class.after_refinement(
        original: "x",
        refined: "y",
        iterations: 2,
        feedback_history: [],
        improved: true,
        confidence: 0.9
      )

      expect(result.maxed_out?(3)).to be false
    end
  end

  describe "#final" do
    it "returns refined when improved" do
      result = described_class.after_refinement(
        original: "first",
        refined: "better",
        iterations: 1,
        feedback_history: [],
        improved: true,
        confidence: 0.9
      )

      expect(result.final).to eq("better")
    end

    it "returns original when not improved" do
      result = described_class.after_refinement(
        original: "first",
        refined: "worse",
        iterations: 1,
        feedback_history: [],
        improved: false,
        confidence: 0.5
      )

      expect(result.final).to eq("first")
    end
  end
end

RSpec.describe Smolagents::Types::RefinementFeedback do
  describe "attributes" do
    it "has all required fields" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "Needs improvement",
        actionable: true,
        confidence: 0.75
      )

      expect(feedback.iteration).to eq(1)
      expect(feedback.source).to eq(:execution)
      expect(feedback.critique).to eq("Needs improvement")
      expect(feedback.actionable).to be true
      expect(feedback.confidence).to eq(0.75)
    end
  end

  describe "#suggests_improvement?" do
    it "returns true when actionable and confidence > 0.5" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "x",
        actionable: true,
        confidence: 0.6
      )

      expect(feedback.suggests_improvement?).to be true
    end

    it "returns false when not actionable" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "x",
        actionable: false,
        confidence: 0.9
      )

      expect(feedback.suggests_improvement?).to be false
    end

    it "returns false when confidence <= 0.5" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "x",
        actionable: true,
        confidence: 0.5
      )

      expect(feedback.suggests_improvement?).to be false
    end

    it "returns false when confidence < 0.5" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "x",
        actionable: true,
        confidence: 0.3
      )

      expect(feedback.suggests_improvement?).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      feedback = described_class.new(
        iteration: 1,
        source: :execution,
        critique: "x",
        actionable: true,
        confidence: 0.8
      )

      expect(feedback).to be_frozen
    end
  end
end
