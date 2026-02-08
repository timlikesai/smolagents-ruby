require "spec_helper"

RSpec.describe Smolagents::Types::TrajectorySegment do
  let(:step1) { Smolagents::Types::ActionStep.new(step_number: 1, observations: "Found results") }
  let(:step2) { Smolagents::Types::ActionStep.new(step_number: 2, observations: "Processed data") }
  let(:step3) { Smolagents::Types::ActionStep.new(step_number: 3, observations: "Formatted output") }
  let(:steps) { [step1, step2, step3] }

  describe ".from_steps" do
    it "creates a segment from steps" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      expect(segment.label).to eq(:search)
      expect(segment.steps).to eq(steps)
      expect(segment.outcome).to eq(:success)
      expect(segment.start_step).to eq(1)
      expect(segment.end_step).to eq(3)
      expect(segment.summary).to be_nil
    end

    it "returns nil for empty steps" do
      segment = described_class.from_steps([], label: :search)

      expect(segment).to be_nil
    end

    it "defaults outcome to :unknown" do
      segment = described_class.from_steps(steps, label: :tool_execution)

      expect(segment.outcome).to eq(:unknown)
    end

    it "freezes the steps array" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment.steps).to be_frozen
    end

    it "creates segment for single step" do
      segment = described_class.from_steps([step1], label: :planning)

      expect(segment.start_step).to eq(1)
      expect(segment.end_step).to eq(1)
      expect(segment.step_count).to eq(1)
    end

    it "handles steps without step_number" do
      planning_step = Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan",
        timing: nil,
        token_usage: nil
      )
      segment = described_class.from_steps([planning_step], label: :planning)

      expect(segment.start_step).to be_nil
      expect(segment.end_step).to be_nil
      expect(segment.step_count).to eq(1)
    end
  end

  describe "#step_count" do
    it "returns the number of steps" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment.step_count).to eq(3)
    end
  end

  describe "#step_range" do
    it "returns a range from start to end step" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment.step_range).to eq(1..3)
    end

    it "returns a single-element range for single step" do
      segment = described_class.from_steps([step2], label: :search)

      expect(segment.step_range).to eq(2..2)
    end
  end

  describe "#success?" do
    it "returns true when outcome is :success" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      expect(segment.success?).to be true
    end

    it "returns false for other outcomes" do
      segment = described_class.from_steps(steps, label: :search, outcome: :failure)

      expect(segment.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true when outcome is :failure" do
      segment = described_class.from_steps(steps, label: :search, outcome: :failure)

      expect(segment.failure?).to be true
    end

    it "returns false for other outcomes" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      expect(segment.failure?).to be false
    end
  end

  describe "#partial?" do
    it "returns true when outcome is :partial" do
      segment = described_class.from_steps(steps, label: :search, outcome: :partial)

      expect(segment.partial?).to be true
    end

    it "returns false for other outcomes" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      expect(segment.partial?).to be false
    end
  end

  describe "#unknown?" do
    it "returns true when outcome is :unknown" do
      segment = described_class.from_steps(steps, label: :search, outcome: :unknown)

      expect(segment.unknown?).to be true
    end

    it "returns false for other outcomes" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      expect(segment.unknown?).to be false
    end
  end

  describe "#with_summary" do
    it "returns a new segment with summary" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)
      with_summary = segment.with_summary("Searched and found 3 results")

      expect(with_summary.summary).to eq("Searched and found 3 results")
      expect(with_summary).not_to eq(segment)
    end

    it "preserves other fields" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)
      with_summary = segment.with_summary("Summary text")

      expect(with_summary.label).to eq(:search)
      expect(with_summary.outcome).to eq(:success)
      expect(with_summary.steps).to eq(steps)
      expect(with_summary.start_step).to eq(1)
      expect(with_summary.end_step).to eq(3)
    end

    it "is immutable (original unchanged)" do
      segment = described_class.from_steps(steps, label: :search)
      segment.with_summary("New summary")

      expect(segment.summary).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      result = segment.to_h

      expect(result[:label]).to eq(:search)
      expect(result[:outcome]).to eq(:success)
      expect(result[:start_step]).to eq(1)
      expect(result[:end_step]).to eq(3)
      expect(result[:step_count]).to eq(3)
    end

    it "includes summary when present" do
      segment = described_class.from_steps(steps, label: :search).with_summary("Test summary")

      expect(segment.to_h[:summary]).to eq("Test summary")
    end

    it "excludes summary when nil" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment.to_h).not_to have_key(:summary)
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      segment = described_class.from_steps(steps, label: :search, outcome: :success)

      matched = case segment
                in { label: :search, outcome: outcome }
                  outcome
                else
                  :no_match
                end

      expect(matched).to eq(:success)
    end
  end

  describe "immutability" do
    it "is a Data.define type" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment).to be_a(Data)
    end

    it "is frozen" do
      segment = described_class.from_steps(steps, label: :search)

      expect(segment).to be_frozen
    end
  end
end
