require "spec_helper"

RSpec.describe Smolagents::Security::RateLimitPolicy do
  describe ".default" do
    subject(:policy) { described_class.default }

    it "creates a moderate rate limit" do
      expect(policy.requests_per_second).to eq(1.0)
    end

    it "allows burst of 3" do
      expect(policy.burst_size).to eq(3)
    end

    it "uses token bucket strategy" do
      expect(policy.strategy).to eq(:token_bucket)
    end

    it "scopes to tool" do
      expect(policy.scope).to eq(:tool)
    end
  end

  describe ".strict" do
    subject(:policy) { described_class.strict }

    it "creates a conservative rate limit" do
      expect(policy.requests_per_second).to eq(0.5)
    end

    it "allows minimal burst" do
      expect(policy.burst_size).to eq(1)
    end

    it "uses fixed window strategy" do
      expect(policy.strategy).to eq(:fixed_window)
    end
  end

  describe ".permissive" do
    subject(:policy) { described_class.permissive }

    it "creates a high rate limit" do
      expect(policy.requests_per_second).to eq(10.0)
    end

    it "allows generous burst" do
      expect(policy.burst_size).to eq(20)
    end

    it "uses global scope" do
      expect(policy.scope).to eq(:global)
    end
  end

  describe ".unlimited" do
    subject(:policy) { described_class.unlimited }

    it "disables rate limiting" do
      expect(policy.requests_per_second).to be_nil
    end

    it "reports as disabled" do
      expect(policy.enabled?).to be false
    end
  end

  describe "#enabled?" do
    it "returns true when requests_per_second is set" do
      policy = described_class.default
      expect(policy.enabled?).to be true
    end

    it "returns false when requests_per_second is nil" do
      policy = described_class.unlimited
      expect(policy.enabled?).to be false
    end
  end

  describe "#min_interval" do
    it "calculates interval from rate" do
      policy = described_class.new(
        requests_per_second: 2.0,
        burst_size: 1,
        strategy: :token_bucket,
        scope: :tool
      )
      expect(policy.min_interval).to eq(0.5)
    end

    it "returns 0.0 when disabled" do
      policy = described_class.unlimited
      expect(policy.min_interval).to eq(0.0)
    end
  end

  describe "strategy predicates" do
    it "detects token bucket" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 1,
        strategy: :token_bucket,
        scope: :tool
      )
      expect(policy.token_bucket?).to be true
      expect(policy.sliding_window?).to be false
      expect(policy.fixed_window?).to be false
    end

    it "detects sliding window" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 1,
        strategy: :sliding_window,
        scope: :tool
      )
      expect(policy.sliding_window?).to be true
    end

    it "detects fixed window" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 1,
        strategy: :fixed_window,
        scope: :tool
      )
      expect(policy.fixed_window?).to be true
    end
  end

  describe "scope predicates" do
    it "detects tool scope" do
      policy = described_class.default
      expect(policy.tool_scoped?).to be true
      expect(policy.global_scoped?).to be false
    end

    it "detects global scope" do
      policy = described_class.permissive
      expect(policy.global_scoped?).to be true
    end
  end

  describe "#merge" do
    it "creates new policy with overrides" do
      original = described_class.default
      merged = original.merge(requests_per_second: 5.0)

      expect(merged.requests_per_second).to eq(5.0)
      expect(merged.burst_size).to eq(3) # unchanged
      expect(original.requests_per_second).to eq(1.0) # original unchanged
    end

    it "accepts hash overrides" do
      original = described_class.default
      merged = original.merge({ burst_size: 10, strategy: :fixed_window })

      expect(merged.burst_size).to eq(10)
      expect(merged.strategy).to eq(:fixed_window)
    end
  end

  describe "#validate!" do
    it "passes for valid policy" do
      policy = described_class.default
      expect { policy.validate! }.not_to raise_error
    end

    it "returns self for chaining" do
      policy = described_class.default
      expect(policy.validate!).to eq(policy)
    end

    it "rejects negative rate" do
      policy = described_class.new(
        requests_per_second: -1.0,
        burst_size: 1,
        strategy: :token_bucket,
        scope: :tool
      )
      expect { policy.validate! }.to raise_error(ArgumentError, /requests_per_second/)
    end

    it "rejects zero rate" do
      policy = described_class.new(
        requests_per_second: 0,
        burst_size: 1,
        strategy: :token_bucket,
        scope: :tool
      )
      expect { policy.validate! }.to raise_error(ArgumentError, /requests_per_second/)
    end

    it "rejects invalid burst" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 0,
        strategy: :token_bucket,
        scope: :tool
      )
      expect { policy.validate! }.to raise_error(ArgumentError, /burst_size/)
    end

    it "rejects invalid strategy" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 1,
        strategy: :invalid,
        scope: :tool
      )
      expect { policy.validate! }.to raise_error(ArgumentError, /strategy/)
    end

    it "rejects invalid scope" do
      policy = described_class.new(
        requests_per_second: 1.0,
        burst_size: 1,
        strategy: :token_bucket,
        scope: :invalid
      )
      expect { policy.validate! }.to raise_error(ArgumentError, /scope/)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      policy = described_class.default

      case policy
      in { requests_per_second: rps, burst_size: burst }
        expect(rps).to eq(1.0)
        expect(burst).to eq(3)
      end
    end
  end
end
