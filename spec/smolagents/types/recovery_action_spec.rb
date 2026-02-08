require "spec_helper"

RSpec.describe Smolagents::Types::RecoveryAction do
  describe "constants" do
    it "defines RETRY action" do
      expect(described_class::RETRY).to eq(:retry)
    end

    it "defines REFORMAT action" do
      expect(described_class::REFORMAT).to eq(:reformat)
    end

    it "defines SWITCH action" do
      expect(described_class::SWITCH).to eq(:switch)
    end

    it "defines TERMINATE action" do
      expect(described_class::TERMINATE).to eq(:terminate)
    end
  end

  describe "::ALL" do
    it "contains all four actions" do
      expect(described_class::ALL).to contain_exactly(:retry, :reformat, :switch, :terminate)
    end

    it "is frozen" do
      expect(described_class::ALL).to be_frozen
    end
  end

  describe ".valid?" do
    it "returns true for RETRY" do
      expect(described_class.valid?(:retry)).to be true
    end

    it "returns true for REFORMAT" do
      expect(described_class.valid?(:reformat)).to be true
    end

    it "returns true for SWITCH" do
      expect(described_class.valid?(:switch)).to be true
    end

    it "returns true for TERMINATE" do
      expect(described_class.valid?(:terminate)).to be true
    end

    it "returns false for invalid action" do
      expect(described_class.valid?(:invalid)).to be false
    end

    it "returns false for nil" do
      expect(described_class.valid?(nil)).to be false
    end

    it "returns false for string (must be symbol)" do
      expect(described_class.valid?("retry")).to be false
    end
  end
end
