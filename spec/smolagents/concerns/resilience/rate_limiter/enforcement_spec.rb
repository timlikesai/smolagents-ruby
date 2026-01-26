require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Enforcement do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RateLimiter::Enforcement
      include Smolagents::Concerns::RateLimiter::Tracking
      include Smolagents::Concerns::RateLimiter::Configuration
      include Smolagents::Concerns::RateLimiter::Callbacks
      include Smolagents::Concerns::RateLimiter::Events

      attr_reader :call_count

      def initialize
        super
        @call_count = 0
      end

      def risky_method
        @call_count += 1
        "result"
      end

      def name
        "test_tool"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "rate limit enforcement" do
    it "includes the module" do
      expect(instance).to be_a(described_class)
    end

    it "tracks call count" do
      expect(instance.call_count).to eq(0)
    end
  end

  describe "#enforce_rate_limit!" do
    context "when rate limiting is disabled (no rate_limit set)" do
      it "allows execution without rate limit configured" do
        expect { instance.enforce_rate_limit! }.not_to raise_error
      end
    end

    context "when rate limiting is enabled" do
      before do
        instance.setup_rate_limiter(10.0) # 10 requests per second
      end

      it "allows first request" do
        expect { instance.enforce_rate_limit! }.not_to raise_error
      end

      it "marks request after successful enforcement" do
        instance.enforce_rate_limit!
        expect(instance.request_count).to eq(1)
      end

      it "raises RateLimitExceeded when called too quickly" do
        instance.enforce_rate_limit!
        # Second call immediately should be rate limited
        expect { instance.enforce_rate_limit! }
          .to raise_error(Smolagents::Concerns::RateLimiter::RateLimitExceeded)
      end

      it "includes retry_after in error" do
        instance.enforce_rate_limit!
        begin
          instance.enforce_rate_limit!
        rescue Smolagents::Concerns::RateLimiter::RateLimitExceeded => e
          expect(e.retry_after).to be > 0
          expect(e.retry_after).to be <= 0.1 # At 10 req/s, wait is ~0.1s
        end
      end
    end
  end

  describe "#with_rate_limit" do
    context "when rate limiting is disabled" do
      it "returns success with block result" do
        result = instance.with_rate_limit { "hello" }
        expect(result).to eq([:success, "hello"])
      end
    end

    context "when rate limiting is enabled" do
      before do
        instance.setup_rate_limiter(10.0)
      end

      it "returns success on first call" do
        result = instance.with_rate_limit { "result" }
        expect(result).to eq([:success, "result"])
      end

      it "returns rate_limited event on second immediate call" do
        instance.with_rate_limit { "first" }
        result = instance.with_rate_limit { "second" }

        expect(result.first).to eq(:rate_limited)
        expect(result.last).to be_a(Smolagents::Events::RateLimitHit)
      end

      it "passes original_request to event" do
        instance.with_rate_limit { "first" }
        result = instance.with_rate_limit(original_request: { query: "test" }) { "second" }

        expect(result.last.original_request).to eq({ query: "test" })
      end
    end
  end

  describe "rate limit states" do
    it "allows execution when no rate limit configured" do
      expect { instance.risky_method }.not_to raise_error
    end

    it "tracks rate limit configuration" do
      instance.setup_rate_limiter(5.0)
      expect(instance.limit_interval).to eq(0.2)
    end
  end

  describe "concurrent enforcement" do
    before do
      instance.setup_rate_limiter(100.0) # High rate to allow many concurrent
    end

    it "handles concurrent requests" do
      results = []
      threads = Array.new(5) do
        Thread.new do
          instance.enforce_rate_limit!
          results << :allowed
        rescue Smolagents::Concerns::RateLimiter::RateLimitExceeded
          results << :rejected
        end
      end

      threads.each(&:join)

      allowed = results.count(:allowed)
      rejected = results.count(:rejected)

      expect(allowed + rejected).to eq(5)
    end
  end

  describe "integration with tracking" do
    before do
      instance.setup_rate_limiter(10.0)
    end

    it "uses rate_limit_ok? for checking" do
      expect(instance.rate_limit_ok?).to be true

      instance.enforce_rate_limit!

      # Immediately after, should not be ok
      expect(instance.rate_limit_ok?).to be false
    end

    it "uses mark_request! for recording" do
      initial_count = instance.request_count

      instance.enforce_rate_limit!

      expect(instance.request_count).to eq(initial_count + 1)
    end
  end

  describe "pattern matching with with_rate_limit" do
    before do
      instance.setup_rate_limiter(10.0)
    end

    it "supports pattern matching for success" do
      case instance.with_rate_limit { "result" }
      in [:success, result]
        expect(result).to eq("result")
      in [:rate_limited, _]
        raise "Should not be rate limited"
      end
    end

    it "supports pattern matching for rate limited" do
      instance.with_rate_limit { "first" }

      case instance.with_rate_limit { "second" }
      in [:success, _]
        raise "Should be rate limited"
      in [:rate_limited, event]
        expect(event).to be_a(Smolagents::Events::RateLimitHit)
      end
    end
  end
end
