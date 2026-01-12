# frozen_string_literal: true

require "smolagents"

RSpec.describe Smolagents::Utilities::Confidence do
  describe ".estimate" do
    let(:base_args) { { steps_taken: 3, max_steps: 10 } }

    it "returns reasonable confidence for neutral output" do
      confidence = described_class.estimate("The result is something.", **base_args)
      expect(confidence).to be_between(0.4, 0.9)
    end

    it "penalizes hitting max steps" do
      normal = described_class.estimate("Result", steps_taken: 5, max_steps: 10)
      at_limit = described_class.estimate("Result", steps_taken: 10, max_steps: 10)

      expect(at_limit).to be < normal
    end

    it "penalizes uncertainty language" do
      certain = described_class.estimate("The answer is 42.", **base_args)
      uncertain = described_class.estimate("Maybe the answer is 42, perhaps.", **base_args)

      expect(uncertain).to be < certain
    end

    it "penalizes refusal language" do
      helpful = described_class.estimate("The capital is Paris.", **base_args)
      refusal = described_class.estimate("I cannot answer that question.", **base_args)

      expect(refusal).to be < helpful
    end

    it "rewards confidence language" do
      neutral = described_class.estimate("The answer is 42.", **base_args)
      confident = described_class.estimate("The answer is definitely 42.", **base_args)

      expect(confident).to be > neutral
    end

    it "rewards specific facts (entities)" do
      vague = described_class.estimate("It happened.", **base_args)
      specific = described_class.estimate("Paris, France on January 15, 2024.", **base_args)

      expect(specific).to be > vague
    end

    it "rewards quick decisions" do
      slow = described_class.estimate("Result", steps_taken: 8, max_steps: 10)
      quick = described_class.estimate("Result", steps_taken: 1, max_steps: 10)

      expect(quick).to be > slow
    end

    it "rewards reasonable length" do
      too_short = described_class.estimate("No", **base_args)
      reasonable = described_class.estimate("The answer to your question is 42.", **base_args)

      expect(reasonable).to be > too_short
    end

    it "heavily penalizes errors" do
      no_error = described_class.estimate("Result", **base_args)
      with_error = described_class.estimate("Result", **base_args, error: StandardError.new("oops"))

      expect(with_error).to be < no_error
      expect(with_error).to be < 0.3
    end

    it "clamps to 0.0-1.0 range" do
      # Extreme positive case
      high = described_class.estimate(
        "Definitely the answer is Paris, France on 2024-01-15.",
        steps_taken: 1,
        max_steps: 10
      )
      expect(high).to be <= 1.0

      # Extreme negative case
      low = described_class.estimate(
        "I cannot answer. Maybe. I'm not sure. I don't know.",
        steps_taken: 10,
        max_steps: 10,
        error: StandardError.new("failed")
      )
      expect(low).to be >= 0.0
    end
  end

  describe ".confident?" do
    it "returns true when above threshold" do
      expect(described_class.confident?(
               "The answer is definitely Paris.",
               steps_taken: 2,
               max_steps: 10,
               threshold: 0.5
             )).to be true
    end

    it "returns false when below threshold" do
      expect(described_class.confident?(
               "I'm not sure, maybe it's something?",
               steps_taken: 10,
               max_steps: 10,
               threshold: 0.5
             )).to be false
    end

    it "uses default threshold of 0.5" do
      expect(described_class.confident?(
               "The result is 42.",
               steps_taken: 3,
               max_steps: 10
             )).to be true
    end
  end

  describe ".level" do
    it "returns :high for confident outputs" do
      level = described_class.level(
        "The answer is definitely Paris, France.",
        steps_taken: 1,
        max_steps: 10
      )
      expect(level).to eq(:high)
    end

    it "returns :medium for moderate outputs" do
      # Neutral output with some uncertainty
      level = described_class.level(
        "I think it might be something related to the topic.",
        steps_taken: 6,
        max_steps: 10
      )
      expect(level).to eq(:medium)
    end

    it "returns :low for uncertain outputs" do
      level = described_class.level(
        "I cannot answer this.",
        steps_taken: 10,
        max_steps: 10
      )
      expect(level).to eq(:low)
    end
  end
end
