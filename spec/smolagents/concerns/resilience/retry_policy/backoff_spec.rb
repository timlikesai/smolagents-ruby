require "smolagents"

RSpec.describe Smolagents::Concerns::RetryPolicyBackoff do
  describe "STRATEGIES" do
    it "defines multipliers for each strategy" do
      expect(described_class::STRATEGIES[:exponential]).to eq(2.0)
      expect(described_class::STRATEGIES[:linear]).to eq(1.5)
      expect(described_class::STRATEGIES[:constant]).to eq(1.0)
    end
  end

  describe ".multiplier_for" do
    it "returns 2.0 for exponential" do
      expect(described_class.multiplier_for(:exponential)).to eq(2.0)
    end

    it "returns 1.5 for linear" do
      expect(described_class.multiplier_for(:linear)).to eq(1.5)
    end

    it "returns 1.0 for constant" do
      expect(described_class.multiplier_for(:constant)).to eq(1.0)
    end

    it "defaults to 1.0 for unknown strategies" do
      expect(described_class.multiplier_for(:unknown)).to eq(1.0)
    end
  end

  describe ".interval_for" do
    context "with exponential backoff" do
      it "doubles each interval" do
        expect(described_class.interval_for(attempt: 0, strategy: :exponential, base: 1.0, max: 30.0)).to eq(1.0)
        expect(described_class.interval_for(attempt: 1, strategy: :exponential, base: 1.0, max: 30.0)).to eq(2.0)
        expect(described_class.interval_for(attempt: 2, strategy: :exponential, base: 1.0, max: 30.0)).to eq(4.0)
        expect(described_class.interval_for(attempt: 3, strategy: :exponential, base: 1.0, max: 30.0)).to eq(8.0)
      end

      it "caps at max_interval" do
        expect(described_class.interval_for(attempt: 10, strategy: :exponential, base: 1.0, max: 30.0)).to eq(30.0)
      end
    end

    context "with linear backoff" do
      it "increases by multiplier each interval" do
        expect(described_class.interval_for(attempt: 0, strategy: :linear, base: 1.0, max: 30.0)).to eq(1.0)
        expect(described_class.interval_for(attempt: 1, strategy: :linear, base: 1.0, max: 30.0)).to eq(1.5)
        expect(described_class.interval_for(attempt: 2, strategy: :linear, base: 1.0, max: 30.0)).to eq(2.25)
      end
    end

    context "with constant backoff" do
      it "always returns base interval" do
        expect(described_class.interval_for(attempt: 0, strategy: :constant, base: 1.0, max: 30.0)).to eq(1.0)
        expect(described_class.interval_for(attempt: 5, strategy: :constant, base: 1.0, max: 30.0)).to eq(1.0)
      end
    end

    context "with jitter" do
      it "adds randomness within jitter range" do
        results = Array.new(10) do
          described_class.interval_for(attempt: 0, strategy: :exponential, base: 1.0, max: 30.0, jitter: 0.5)
        end

        expect(results.min).to be >= 1.0
        expect(results.max).to be <= 1.5
        expect(results.uniq.size).to be > 1
      end
    end
  end

  describe ".add_jitter" do
    it "adds randomness within the specified range" do
      results = Array.new(20) { described_class.add_jitter(1.0, 0.5) }

      expect(results.min).to be >= 1.0
      expect(results.max).to be <= 1.5
    end

    it "does not exceed the jitter range" do
      100.times do
        result = described_class.add_jitter(10.0, 2.0)
        expect(result).to be >= 10.0
        expect(result).to be <= 12.0
      end
    end
  end

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to be_a(Hash)
      expect(methods.keys).to include(:multiplier_for, :interval_for, :add_jitter)
    end
  end
end
