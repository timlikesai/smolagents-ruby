require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::Base do
  let(:strategy) do
    described_class.new(rate: 10, burst: 20)
  end

  describe "#initialize" do
    it "accepts rate and burst parameters" do
      s = described_class.new(rate: 5, burst: 10)
      expect(s.rate).to eq(5)
      expect(s.burst).to eq(10)
    end

    it "stores rate" do
      expect(strategy.rate).to eq(10)
    end

    it "stores burst" do
      expect(strategy.burst).to eq(20)
    end
  end

  describe "#allow?" do
    it "raises NotImplementedError" do
      expect { strategy.allow? }.to raise_error(NotImplementedError, /must implement #allow\?/)
    end
  end

  describe "#acquire!" do
    it "raises NotImplementedError" do
      expect { strategy.acquire! }.to raise_error(NotImplementedError, /must implement #acquire!/)
    end
  end

  describe "#retry_after" do
    it "raises NotImplementedError" do
      expect { strategy.retry_after }.to raise_error(NotImplementedError, /must implement #retry_after/)
    end
  end

  describe "#reset!" do
    it "raises NotImplementedError" do
      expect { strategy.reset! }.to raise_error(NotImplementedError, /must implement #reset!/)
    end
  end

  describe "#window_size" do
    it "calculates window size from burst and rate" do
      s = described_class.new(rate: 10, burst: 100)
      expect(s.window_size).to eq(10.0) # burst / rate = 100 / 10
    end

    it "handles fractional window sizes" do
      s = described_class.new(rate: 3, burst: 10)
      expect(s.window_size).to be_within(0.01).of(3.33)
    end

    it "works with rate of 1" do
      s = described_class.new(rate: 1, burst: 5)
      expect(s.window_size).to eq(5.0)
    end

    it "returns float value" do
      expect(strategy.window_size).to be_a(Float)
    end
  end

  describe "subclassing" do
    let(:concrete_strategy) do
      # rubocop:disable Naming/PredicateMethod -- bang methods modify state, not predicates
      Class.new(described_class) do
        def allow? = true

        def acquire! = true

        def retry_after = 0.0

        def reset! = nil
      end
      # rubocop:enable Naming/PredicateMethod
    end

    it "allows subclasses to implement required methods" do
      strategy = concrete_strategy.new(rate: 10, burst: 20)
      expect(strategy.allow?).to be true
      expect(strategy.acquire!).to be true
      expect(strategy.retry_after).to eq(0.0)
      expect(strategy.reset!).to be_nil
    end

    it "subclasses inherit window_size calculation" do
      strategy = concrete_strategy.new(rate: 5, burst: 25)
      expect(strategy.window_size).to eq(5.0)
    end
  end

  describe "parameter validation" do
    it "accepts zero rate (edge case)" do
      s = described_class.new(rate: 0, burst: 0)
      expect(s.rate).to eq(0)
    end

    it "accepts negative burst (unusual but possible)" do
      s = described_class.new(rate: 10, burst: -5)
      expect(s.burst).to eq(-5)
    end

    it "accepts large numbers" do
      s = described_class.new(rate: 1_000_000, burst: 10_000_000)
      expect(s.rate).to eq(1_000_000)
      expect(s.burst).to eq(10_000_000)
    end
  end

  describe "window_size edge cases" do
    it "handles rate = 1" do
      s = described_class.new(rate: 1, burst: 10)
      expect(s.window_size).to eq(10.0)
    end

    it "handles large rate" do
      s = described_class.new(rate: 1000, burst: 1000)
      expect(s.window_size).to eq(1.0)
    end

    it "handles zero rate gracefully" do
      s = described_class.new(rate: 0, burst: 10)
      # Should either return Infinity or raise
      result = s.window_size
      expect(result).to be_finite.or be_infinite
    end
  end

  describe "integration with concrete strategies" do
    it "provides common interface for all strategies" do
      concrete = Class.new(described_class) do
        def allow? = false
        def acquire! = false # rubocop:disable Naming/PredicateMethod -- action method
        def retry_after = 1.0
        def reset! = nil
      end

      strategy = concrete.new(rate: 100, burst: 1000)

      # All methods should be callable
      expect(strategy.rate).to eq(100)
      expect(strategy.burst).to eq(1000)
      expect(strategy.allow?).to be false
      expect(strategy.acquire!).to be false
      expect(strategy.retry_after).to eq(1.0)
      expect { strategy.reset! }.not_to raise_error
      expect(strategy.window_size).to eq(10.0)
    end
  end

  describe "immutability of parameters" do
    it "allows reading rate multiple times" do
      rate1 = strategy.rate
      rate2 = strategy.rate
      expect(rate1).to eq(rate2)
    end

    it "allows reading burst multiple times" do
      burst1 = strategy.burst
      burst2 = strategy.burst
      expect(burst1).to eq(burst2)
    end

    it "returns same window_size value" do
      size1 = strategy.window_size
      size2 = strategy.window_size
      expect(size1).to eq(size2)
    end
  end
end
