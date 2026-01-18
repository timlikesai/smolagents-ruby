require "smolagents/testing"

RSpec.describe Smolagents::Testing::TestResult do
  let(:test_case) do
    Smolagents::Testing::TestCase.new(
      name: "arithmetic_test",
      capability: :basic_reasoning,
      task: "What is 2 + 2?",
      max_steps: 5
    )
  end

  describe "initialization" do
    it "creates result with required fields" do
      result = described_class.new(test_case:, passed: true)

      expect(result.test_case).to eq(test_case)
      expect(result.passed).to be true
    end

    it "applies default values for optional fields" do
      result = described_class.new(test_case:, passed: true)

      expect(result.output).to be_nil
      expect(result.error).to be_nil
      expect(result.duration).to eq(0)
      expect(result.steps).to eq(0)
      expect(result.tokens).to eq(0)
      expect(result.partial_score).to be_nil
      expect(result.raw_steps).to eq([])
    end

    it "accepts all optional parameters" do
      error = RuntimeError.new("Test error")
      raw_steps = [{ step: 1 }, { step: 2 }]

      result = described_class.new(
        test_case:,
        passed: false,
        output: "partial result",
        error:,
        duration: 5.5,
        steps: 3,
        tokens: 250,
        partial_score: 0.7,
        raw_steps:
      )

      expect(result.output).to eq("partial result")
      expect(result.error).to eq(error)
      expect(result.duration).to eq(5.5)
      expect(result.steps).to eq(3)
      expect(result.tokens).to eq(250)
      expect(result.partial_score).to eq(0.7)
      expect(result.raw_steps).to eq(raw_steps)
    end
  end

  describe "#success?" do
    it "returns true when passed and no error" do
      result = described_class.new(test_case:, passed: true)

      expect(result.success?).to be true
    end

    it "returns false when passed but has error" do
      result = described_class.new(test_case:, passed: true, error: RuntimeError.new("oops"))

      expect(result.success?).to be false
    end

    it "returns false when not passed" do
      result = described_class.new(test_case:, passed: false)

      expect(result.success?).to be false
    end

    it "returns false when not passed even with error" do
      result = described_class.new(test_case:, passed: false, error: RuntimeError.new("fail"))

      expect(result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true when not passed" do
      result = described_class.new(test_case:, passed: false)

      expect(result.failure?).to be true
    end

    it "returns false when passed" do
      result = described_class.new(test_case:, passed: true)

      expect(result.failure?).to be false
    end
  end

  describe "#efficiency" do
    it "returns 1.0 when passed with zero steps" do
      result = described_class.new(test_case:, passed: true, steps: 0)

      expect(result.efficiency).to eq(1.0)
    end

    it "returns 0.6 when passed using 2 of 5 steps" do
      result = described_class.new(test_case:, passed: true, steps: 2)

      expect(result.efficiency).to eq(0.6)
    end

    it "returns 0.0 when passed using all steps" do
      result = described_class.new(test_case:, passed: true, steps: 5)

      expect(result.efficiency).to eq(0.0)
    end

    it "clamps to 0.0 when steps exceed max_steps" do
      result = described_class.new(test_case:, passed: true, steps: 10)

      expect(result.efficiency).to eq(0.0)
    end

    it "returns 0.0 when failed regardless of steps" do
      result = described_class.new(test_case:, passed: false, steps: 1)

      expect(result.efficiency).to eq(0.0)
    end

    it "handles test case with zero max_steps" do
      zero_steps_case = Smolagents::Testing::TestCase.new(
        name: "zero_steps",
        capability: :basic,
        task: "test",
        max_steps: 0
      )
      result = described_class.new(test_case: zero_steps_case, passed: true, steps: 0)

      expect(result.efficiency).to eq(0.0)
    end
  end

  describe "#tokens_per_step" do
    it "returns 0.0 when no steps taken" do
      result = described_class.new(test_case:, passed: true, steps: 0, tokens: 100)

      expect(result.tokens_per_step).to eq(0.0)
    end

    it "calculates average tokens per step" do
      result = described_class.new(test_case:, passed: true, steps: 4, tokens: 200)

      expect(result.tokens_per_step).to eq(50.0)
    end

    it "handles fractional results" do
      result = described_class.new(test_case:, passed: true, steps: 3, tokens: 100)

      expect(result.tokens_per_step).to be_within(0.01).of(33.33)
    end
  end

  describe "#to_h" do
    it "returns hash with test case name" do
      result = described_class.new(test_case:, passed: true, output: "4")
      hash = result.to_h

      expect(hash[:test_case]).to eq("arithmetic_test")
    end

    it "includes all scalar fields" do
      result = described_class.new(
        test_case:,
        passed: true,
        output: "4",
        duration: 1.5,
        steps: 2,
        tokens: 100
      )
      hash = result.to_h

      expect(hash).to include(
        passed: true,
        output: "4",
        duration: 1.5,
        steps: 2,
        tokens: 100
      )
    end

    it "extracts error message from exception" do
      error = RuntimeError.new("Something went wrong")
      result = described_class.new(test_case:, passed: false, error:)
      hash = result.to_h

      expect(hash[:error]).to eq("Something went wrong")
    end

    it "returns nil for error when no error present" do
      result = described_class.new(test_case:, passed: true)
      hash = result.to_h

      expect(hash[:error]).to be_nil
    end

    it "includes calculated efficiency" do
      result = described_class.new(test_case:, passed: true, steps: 2)
      hash = result.to_h

      expect(hash[:efficiency]).to eq(0.6)
    end

    it "excludes raw_steps from hash" do
      result = described_class.new(test_case:, passed: true, raw_steps: [{ step: 1 }])
      hash = result.to_h

      expect(hash).not_to have_key(:raw_steps)
    end

    it "excludes partial_score from hash" do
      result = described_class.new(test_case:, passed: true, partial_score: 0.5)
      hash = result.to_h

      expect(hash).not_to have_key(:partial_score)
    end
  end

  describe "pattern matching" do
    it "matches on passed status" do
      result = described_class.new(test_case:, passed: true)

      matched = case result
                in passed: true
                  "passed"
                else
                  "failed"
                end

      expect(matched).to eq("passed")
    end

    it "matches on test_case name" do
      result = described_class.new(test_case:, passed: true)

      matched = case result
                in test_case: "arithmetic_test"
                  "matched"
                else
                  "not matched"
                end

      expect(matched).to eq("matched")
    end

    it "matches on efficiency" do
      result = described_class.new(test_case:, passed: true, steps: 2)

      matched = case result
                in efficiency: 0.6
                  "efficient"
                else
                  "not efficient"
                end

      expect(matched).to eq("efficient")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      result = described_class.new(test_case:, passed: true)

      expect(result).to be_frozen
    end

    it "with method returns new frozen instance" do
      result = described_class.new(test_case:, passed: true, steps: 1)
      updated = result.with(steps: 2)

      expect(updated).to be_frozen
      expect(result.steps).to eq(1)
      expect(updated.steps).to eq(2)
    end
  end
end
