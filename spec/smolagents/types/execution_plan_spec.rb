RSpec.describe Smolagents::Types::ExecutionPlan do
  let(:parallel_stage) { Smolagents::Types::ExecutionStage.parallel(:broad, :deep) }
  let(:sequential_stage) { Smolagents::Types::ExecutionStage.sequential(:synthesizer) }

  describe ".create" do
    it "creates a plan from stages" do
      plan = described_class.create([parallel_stage, sequential_stage])

      expect(plan.stages.size).to eq(2)
    end

    it "validates all stages" do
      invalid_stage = Smolagents::Types::ExecutionStage.new(agents: [], mode: :parallel)

      expect { described_class.create([invalid_stage]) }.to raise_error(ArgumentError)
    end

    it "freezes stages" do
      plan = described_class.create([parallel_stage])

      expect(plan.stages).to be_frozen
    end
  end

  describe "#to_instructions" do
    it "generates human-readable instructions" do
      plan = described_class.create([parallel_stage, sequential_stage])

      instructions = plan.to_instructions

      expect(instructions).to include("Stage 1")
      expect(instructions).to include("Stage 2")
      expect(instructions).to include("broad, deep")
      expect(instructions).to include("in parallel")
      expect(instructions).to include("synthesizer")
      expect(instructions).to include("sequentially")
    end

    it "describes parallel stages correctly" do
      plan = described_class.create([parallel_stage])

      expect(plan.to_instructions).to include("in parallel")
    end

    it "describes sequential stages correctly" do
      plan = described_class.create([sequential_stage])

      expect(plan.to_instructions).to include("sequentially")
    end
  end

  describe "#parallel_stages" do
    it "returns only parallel stages" do
      plan = described_class.create([parallel_stage, sequential_stage])

      expect(plan.parallel_stages.size).to eq(1)
      expect(plan.parallel_stages.first.parallel?).to be true
    end
  end

  describe "#sequential_stages" do
    it "returns only sequential stages" do
      plan = described_class.create([parallel_stage, sequential_stage])

      expect(plan.sequential_stages.size).to eq(1)
      expect(plan.sequential_stages.first.sequential?).to be true
    end
  end

  describe "#empty?" do
    it "returns true for empty plan" do
      plan = described_class.create([])

      expect(plan.empty?).to be true
    end

    it "returns false for non-empty plan" do
      plan = described_class.create([parallel_stage])

      expect(plan.empty?).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      plan = described_class.create([parallel_stage])

      expect(plan).to be_frozen
    end
  end
end
