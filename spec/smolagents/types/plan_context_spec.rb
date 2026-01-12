require "smolagents"

RSpec.describe Smolagents::PlanContext do
  describe ".initial" do
    it "creates initial plan context with given plan" do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      context = described_class.initial("Step 1: Do something\nStep 2: Do another thing")

      expect(context.plan).to eq("Step 1: Do something\nStep 2: Do another thing")
      expect(context.state).to eq(:initial)
      expect(context.generated_at).to eq(freeze_time)
      expect(context.step_number).to eq(0)
    end
  end

  describe ".uninitialized" do
    it "creates uninitialized plan context" do
      context = described_class.uninitialized

      expect(context.plan).to be_nil
      expect(context.state).to eq(:uninitialized)
      expect(context.generated_at).to be_nil
      expect(context.step_number).to be_nil
    end
  end

  describe "#update" do
    it "returns new context with updated plan" do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      original = described_class.initial("Original plan")
      updated = original.update("Updated plan", at_step: 3)

      expect(updated.plan).to eq("Updated plan")
      expect(updated.state).to eq(:active)
      expect(updated.generated_at).to eq(freeze_time)
      expect(updated.step_number).to eq(3)
    end

    it "does not modify original context" do
      original = described_class.initial("Original plan")
      original.update("Updated plan", at_step: 3)

      expect(original.plan).to eq("Original plan")
      expect(original.state).to eq(:initial)
    end
  end

  describe "#stale?" do
    context "with uninitialized context" do
      let(:context) { described_class.uninitialized }

      it "returns true when interval is positive" do
        expect(context.stale?(0, 3)).to be true
        expect(context.stale?(5, 3)).to be true
      end

      it "returns false when interval is nil or zero" do
        expect(context.stale?(0, nil)).to be false
        expect(context.stale?(0, 0)).to be false
      end
    end

    context "with initialized context" do
      let(:context) { described_class.initial("Plan") }

      it "returns true when step is divisible by interval" do
        expect(context.stale?(0, 3)).to be true
        expect(context.stale?(3, 3)).to be true
        expect(context.stale?(6, 3)).to be true
      end

      it "returns false when step is not divisible by interval" do
        expect(context.stale?(1, 3)).to be false
        expect(context.stale?(2, 3)).to be false
        expect(context.stale?(4, 3)).to be false
      end

      it "returns false when interval is nil" do
        expect(context.stale?(3, nil)).to be false
      end
    end
  end

  describe "#initialized?" do
    it "returns false for uninitialized context" do
      context = described_class.uninitialized
      expect(context.initialized?).to be false
    end

    it "returns true for initial context" do
      context = described_class.initial("Plan")
      expect(context.initialized?).to be true
    end

    it "returns true for updated (active) context" do
      context = described_class.initial("Plan").update("Updated", at_step: 1)
      expect(context.initialized?).to be true
    end
  end

  describe "#active?" do
    it "returns false for uninitialized context" do
      context = described_class.uninitialized
      expect(context.active?).to be false
    end

    it "returns false for initial context" do
      context = described_class.initial("Plan")
      expect(context.active?).to be false
    end

    it "returns true for updated context" do
      context = described_class.initial("Plan").update("Updated", at_step: 1)
      expect(context.active?).to be true
    end
  end

  describe "#to_h" do
    it "returns hash representation with ISO8601 timestamp" do
      freeze_time = Time.new(2025, 1, 15, 12, 0, 0, "+00:00")
      allow(Time).to receive(:now).and_return(freeze_time)

      context = described_class.initial("Test plan")
      result = context.to_h

      expect(result[:plan]).to eq("Test plan")
      expect(result[:state]).to eq(:initial)
      expect(result[:generated_at]).to eq(freeze_time.iso8601)
      expect(result[:step_number]).to eq(0)
    end

    it "omits nil values" do
      context = described_class.uninitialized
      result = context.to_h

      expect(result).to eq({ state: :uninitialized })
      expect(result.key?(:plan)).to be false
      expect(result.key?(:generated_at)).to be false
      expect(result.key?(:step_number)).to be false
    end
  end

  describe "immutability" do
    it "is immutable via Data.define" do
      context = described_class.initial("Plan")

      expect { context.plan = "Other" }.to raise_error(NoMethodError)
    end

    it "uses with() internally for updates" do
      context = described_class.initial("Plan")
      updated = context.update("Updated", at_step: 1)

      expect(context).not_to eq(updated)
      expect(context.plan).not_to eq(updated.plan)
    end
  end
end
