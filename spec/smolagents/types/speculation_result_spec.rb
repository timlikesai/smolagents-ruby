require "spec_helper"

RSpec.describe Smolagents::Types::SpeculationResult do
  let(:tool_call) { Smolagents::Types::ToolCall.new(name: "search", arguments: { "q" => "test" }, id: "tc_1") }
  let(:prediction) { Smolagents::Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence: 0.85) }

  describe "type behavior" do
    let(:instance) do
      described_class.executable(prediction:, cost: 100)
    end

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"
  end

  describe ".executable" do
    it "creates result with executable feasibility" do
      result = described_class.executable(prediction:, cost: 100)

      expect(result.prediction).to eq(prediction)
      expect(result.feasibility).to eq(:executable)
      expect(result.feasibility_reasons).to be_empty
      expect(result.estimated_cost).to eq(100)
      expect(result.confidence).to eq(0.85)
      expect(result.recommendations).to eq([:execute])
    end

    it "works without cost" do
      result = described_class.executable(prediction:)

      expect(result.estimated_cost).to be_nil
    end
  end

  describe ".uncertain" do
    let(:reasons) { ["Low confidence", "Budget warning"] }

    it "creates result with uncertain feasibility" do
      result = described_class.uncertain(prediction:, reasons:, cost: 75)

      expect(result.feasibility).to eq(:uncertain)
      expect(result.feasibility_reasons).to eq(reasons)
      expect(result.estimated_cost).to eq(75)
      expect(result.recommendations).to eq(%i[validate delegate])
    end

    it "works without cost" do
      result = described_class.uncertain(prediction:, reasons:)

      expect(result.estimated_cost).to be_nil
    end
  end

  describe ".infeasible" do
    let(:reasons) { ["Unknown tool: nonexistent"] }

    it "creates result with infeasible feasibility" do
      result = described_class.infeasible(prediction:, reasons:)

      expect(result.feasibility).to eq(:infeasible)
      expect(result.feasibility_reasons).to eq(reasons)
      expect(result.estimated_cost).to be_nil
      expect(result.recommendations).to eq([:delegate])
    end
  end

  describe "feasibility predicates" do
    it "#executable? returns true only for executable" do
      executable = described_class.executable(prediction:)
      uncertain = described_class.uncertain(prediction:, reasons: ["test"])
      infeasible = described_class.infeasible(prediction:, reasons: ["test"])

      expect(executable.executable?).to be true
      expect(uncertain.executable?).to be false
      expect(infeasible.executable?).to be false
    end

    it "#uncertain? returns true only for uncertain" do
      executable = described_class.executable(prediction:)
      uncertain = described_class.uncertain(prediction:, reasons: ["test"])
      infeasible = described_class.infeasible(prediction:, reasons: ["test"])

      expect(executable.uncertain?).to be false
      expect(uncertain.uncertain?).to be true
      expect(infeasible.uncertain?).to be false
    end

    it "#infeasible? returns true only for infeasible" do
      executable = described_class.executable(prediction:)
      uncertain = described_class.uncertain(prediction:, reasons: ["test"])
      infeasible = described_class.infeasible(prediction:, reasons: ["test"])

      expect(executable.infeasible?).to be false
      expect(uncertain.infeasible?).to be false
      expect(infeasible.infeasible?).to be true
    end
  end

  describe "recommendation predicates" do
    describe "#should_execute?" do
      it "returns true for executable results" do
        result = described_class.executable(prediction:)

        expect(result.should_execute?).to be true
      end

      it "returns false for uncertain results" do
        result = described_class.uncertain(prediction:, reasons: ["test"])

        expect(result.should_execute?).to be false
      end

      it "returns false for infeasible results" do
        result = described_class.infeasible(prediction:, reasons: ["test"])

        expect(result.should_execute?).to be false
      end
    end

    describe "#should_validate?" do
      it "returns false for executable results" do
        result = described_class.executable(prediction:)

        expect(result.should_validate?).to be false
      end

      it "returns true for uncertain results" do
        result = described_class.uncertain(prediction:, reasons: ["test"])

        expect(result.should_validate?).to be true
      end

      it "returns false for infeasible results" do
        result = described_class.infeasible(prediction:, reasons: ["test"])

        expect(result.should_validate?).to be false
      end
    end

    describe "#should_delegate?" do
      it "returns false for executable results" do
        result = described_class.executable(prediction:)

        expect(result.should_delegate?).to be false
      end

      it "returns true for uncertain results" do
        result = described_class.uncertain(prediction:, reasons: ["test"])

        expect(result.should_delegate?).to be true
      end

      it "returns true for infeasible results" do
        result = described_class.infeasible(prediction:, reasons: ["test"])

        expect(result.should_delegate?).to be true
      end
    end
  end

  describe "feasibility_reasons array" do
    it "is empty for executable" do
      result = described_class.executable(prediction:)

      expect(result.feasibility_reasons).to eq([])
    end

    it "preserves multiple reasons for uncertain" do
      reasons = ["Budget warning", "Low confidence", "Complex args"]
      result = described_class.uncertain(prediction:, reasons:)

      expect(result.feasibility_reasons).to eq(reasons)
      expect(result.feasibility_reasons.size).to eq(3)
    end

    it "preserves reasons for infeasible" do
      reasons = ["Unknown tool: xyz"]
      result = described_class.infeasible(prediction:, reasons:)

      expect(result.feasibility_reasons).to eq(reasons)
    end
  end

  describe "confidence propagation" do
    it "uses confidence from prediction" do
      high_conf = Smolagents::Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence: 0.95)
      low_conf = Smolagents::Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence: 0.25)

      high_result = described_class.executable(prediction: high_conf)
      low_result = described_class.uncertain(prediction: low_conf, reasons: ["low"])

      expect(high_result.confidence).to eq(0.95)
      expect(low_result.confidence).to eq(0.25)
    end
  end
end
