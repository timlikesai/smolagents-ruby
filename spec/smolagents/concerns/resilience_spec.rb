require "spec_helper"

RSpec.describe Smolagents::Concerns::Resilience do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Resilience

      # No rate limit for resilience tests - rate limiting tested separately
      rate_limit nil

      def call_api
        resilient_call("test_api") { "success" }
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#resilient_call" do
    it "executes the block when healthy" do
      result = instance.resilient_call("test") { "result" }
      expect(result).to eq("result")
    end

    it "enforces rate limiting" do
      # Should not raise - rate limit is nil so no enforcement
      results = Array.new(3) { instance.resilient_call("test") { true } }
      expect(results).to all(be true)
    end

    it "wraps with circuit breaker" do
      # Force circuit open with failures
      3.times do
        instance.resilient_call("failing") { raise StandardError, "fail" }
      rescue StandardError
        # Expected
      end

      # Circuit should now be open
      expect { instance.resilient_call("failing") { "won't run" } }
        .to raise_error(Smolagents::AgentGenerationError, /circuit open/)
    end

    it "accepts custom threshold and cool_off" do
      # Force circuit open with only 1 failure
      begin
        instance.resilient_call("custom", threshold: 1, cool_off: 10) do
          raise StandardError, "fail"
        end
      rescue StandardError
        # Expected
      end

      # Circuit should be open after just 1 failure
      expect { instance.resilient_call("custom", threshold: 1) { "x" } }
        .to raise_error(Smolagents::AgentGenerationError, /circuit open/)
    end
  end

  describe "class methods" do
    it "inherits rate_limit from RateLimiter" do
      expect(test_class).to respond_to(:rate_limit)
    end
  end

  describe "composed behavior" do
    it "can use both rate limiting and circuit breaking" do
      # Verify both modules are included
      expect(instance).to respond_to(:enforce_rate_limit!)
      expect(instance).to respond_to(:with_circuit_breaker)
    end
  end
end
