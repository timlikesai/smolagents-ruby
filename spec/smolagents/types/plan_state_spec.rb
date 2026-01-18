require "smolagents"

RSpec.describe Smolagents::PlanState do
  describe "constants" do
    it "defines all plan states" do
      expect(described_class::UNINITIALIZED).to eq(:uninitialized)
      expect(described_class::INITIAL).to eq(:initial)
      expect(described_class::ACTIVE).to eq(:active)
      expect(described_class::UPDATING).to eq(:updating)
    end

    it "defines ALL as frozen array of all states" do
      expect(described_class::ALL).to contain_exactly(:uninitialized, :initial, :active, :updating)
      expect(described_class::ALL).to be_frozen
    end
  end

  describe ".uninitialized?" do
    it "returns true for UNINITIALIZED" do
      expect(described_class.uninitialized?(:uninitialized)).to be true
    end

    it "returns false for other states" do
      expect(described_class.uninitialized?(:initial)).to be false
      expect(described_class.uninitialized?(:active)).to be false
    end
  end

  describe ".initial?" do
    it "returns true for INITIAL" do
      expect(described_class.initial?(:initial)).to be true
    end

    it "returns false for other states" do
      expect(described_class.initial?(:uninitialized)).to be false
      expect(described_class.initial?(:active)).to be false
    end
  end

  describe ".active?" do
    it "returns true for ACTIVE" do
      expect(described_class.active?(:active)).to be true
    end

    it "returns false for other states" do
      expect(described_class.active?(:uninitialized)).to be false
      expect(described_class.active?(:initial)).to be false
    end
  end

  describe ".updating?" do
    it "returns true for UPDATING" do
      expect(described_class.updating?(:updating)).to be true
    end

    it "returns false for other states" do
      expect(described_class.updating?(:active)).to be false
    end
  end

  describe ".valid?" do
    it "returns true for valid states" do
      described_class::ALL.each do |state|
        expect(described_class.valid?(state)).to be true
      end
    end

    it "returns false for invalid states" do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe ".needs_update?" do
    context "with nil or zero interval" do
      it "returns false for nil interval" do
        expect(described_class.needs_update?(:active, 5, nil)).to be false
      end

      it "returns false for zero interval" do
        expect(described_class.needs_update?(:active, 5, 0)).to be false
      end

      it "returns false for negative interval" do
        expect(described_class.needs_update?(:active, 5, -1)).to be false
      end
    end

    context "with uninitialized state" do
      it "returns true regardless of step_number" do
        expect(described_class.needs_update?(:uninitialized, 0, 3)).to be true
        expect(described_class.needs_update?(:uninitialized, 1, 3)).to be true
        expect(described_class.needs_update?(:uninitialized, 5, 3)).to be true
      end
    end

    context "with initialized state" do
      it "returns true when step_number is divisible by interval" do
        expect(described_class.needs_update?(:active, 0, 3)).to be true
        expect(described_class.needs_update?(:active, 3, 3)).to be true
        expect(described_class.needs_update?(:active, 6, 3)).to be true
      end

      it "returns false when step_number is not divisible by interval" do
        expect(described_class.needs_update?(:active, 1, 3)).to be false
        expect(described_class.needs_update?(:active, 2, 3)).to be false
        expect(described_class.needs_update?(:active, 4, 3)).to be false
      end
    end
  end

  describe ".transition" do
    it "transitions from uninitialized to initial when no plan exists" do
      result = described_class.transition(:uninitialized, has_plan: false)
      expect(result).to eq(:initial)
    end

    it "stays uninitialized when already has plan" do
      result = described_class.transition(:uninitialized, has_plan: true)
      expect(result).to eq(:uninitialized)
    end

    it "transitions from initial to active when plan exists" do
      result = described_class.transition(:initial, has_plan: true)
      expect(result).to eq(:active)
    end

    it "stays initial when no plan" do
      result = described_class.transition(:initial, has_plan: false)
      expect(result).to eq(:initial)
    end

    it "transitions from updating to active when plan exists" do
      result = described_class.transition(:updating, has_plan: true)
      expect(result).to eq(:active)
    end

    it "stays active when already active" do
      result = described_class.transition(:active, has_plan: true)
      expect(result).to eq(:active)

      result = described_class.transition(:active, has_plan: false)
      expect(result).to eq(:active)
    end
  end
end
