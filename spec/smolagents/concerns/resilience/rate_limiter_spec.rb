require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter do
  let(:limiter_class) do
    Class.new do
      include Smolagents::Concerns::RateLimiter

      rate_limit 10.0 # 10 requests per second

      def name
        "test_limiter"
      end
    end
  end

  let(:limiter) { limiter_class.new }

  describe ".rate_limit" do
    it "sets class-level default rate limit" do
      expect(limiter_class.default_rate_limit).to eq(10.0)
    end
  end

  describe "#rate_limit_ok?" do
    it "returns true for first request" do
      expect(limiter.rate_limit_ok?).to be true
    end

    it "returns false after marking request within interval" do
      limiter.mark_request!

      expect(limiter.rate_limit_ok?).to be false
    end

    it "returns true when rate limit is nil" do
      no_limit_class = Class.new do
        include Smolagents::Concerns::RateLimiter

        rate_limit nil
      end

      expect(no_limit_class.new.rate_limit_ok?).to be true
    end
  end

  describe "#retry_after" do
    it "returns 0.0 for first request" do
      expect(limiter.retry_after).to eq(0.0)
    end

    it "returns time until next allowed request" do
      limiter.mark_request!

      expect(limiter.retry_after).to be >= 0
      expect(limiter.retry_after).to be <= 0.1 # 10 req/s = 0.1s interval
    end

    it "returns 0.0 when rate limit is nil" do
      no_limit_class = Class.new do
        include Smolagents::Concerns::RateLimiter

        rate_limit nil
      end

      expect(no_limit_class.new.retry_after).to eq(0.0)
    end
  end

  describe "#rate_limit_event" do
    it "creates RateLimitHit event" do
      limiter.mark_request!
      original = Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})

      event = limiter.rate_limit_event(original_request: original)

      expect(event).to be_a(Smolagents::Events::RateLimitHit)
      expect(event.tool_name).to eq("test_limiter")
      expect(event.retry_after).to be >= 0
      expect(event.original_request).to eq(original)
    end

    it "uses class name when name method not available" do
      named_class = Class.new do
        include Smolagents::Concerns::RateLimiter

        rate_limit 10.0

        def self.name
          "NamedTestClass"
        end
      end.new
      named_class.mark_request!

      event = named_class.rate_limit_event

      expect(event.tool_name).to eq("NamedTestClass")
    end
  end

  describe "#with_rate_limit" do
    it "returns [:success, result] when rate limit allows" do
      result = limiter.with_rate_limit { "result" }

      expect(result).to eq([:success, "result"])
    end

    it "returns [:rate_limited, event] when rate limit exceeded" do
      limiter.mark_request!

      result = limiter.with_rate_limit { "should not run" }

      expect(result.first).to eq(:rate_limited)
      expect(result.last).to be_a(Smolagents::Events::RateLimitHit)
    end

    it "passes original_request to event" do
      limiter.mark_request!
      original = Smolagents::Events::ToolCallRequested.create(tool_name: "test", args: {})

      result = limiter.with_rate_limit(original_request: original) { "x" }

      expect(result.last.original_request).to eq(original)
    end

    it "does not execute block when rate limited" do
      limiter.mark_request!
      executed = false

      limiter.with_rate_limit { executed = true }

      expect(executed).to be false
    end

    it "notifies callbacks when rate limited" do
      notified = false
      limiter.on_rate_limited { |_| notified = true }
      limiter.mark_request!

      limiter.with_rate_limit { "x" }

      expect(notified).to be true
    end
  end

  describe "#on_rate_limited" do
    it "registers callback for rate limit events" do
      callbacks = []
      limiter.on_rate_limited { |wait| callbacks << wait }
      limiter.mark_request!

      limiter.with_rate_limit { "x" }

      expect(callbacks.size).to eq(1)
      expect(callbacks.first).to be >= 0
    end

    it "returns self for chaining" do
      result = limiter.on_rate_limited { nil }

      expect(result).to eq(limiter)
    end
  end

  describe "#enforce_rate_limit!" do
    it "does not raise for first request" do
      expect { limiter.enforce_rate_limit! }.not_to raise_error
    end

    it "raises RateLimitExceeded when limit exceeded" do
      limiter.mark_request!

      expect { limiter.enforce_rate_limit! }
        .to raise_error(Smolagents::Concerns::RateLimiter::RateLimitExceeded)
    end

    it "includes retry_after in exception" do
      limiter.mark_request!

      begin
        limiter.enforce_rate_limit!
      rescue Smolagents::Concerns::RateLimiter::RateLimitExceeded => e
        expect(e.retry_after).to be >= 0
        expect(e.tool_name).to eq("test_limiter")
      end
    end
  end

  describe "pattern matching with event results" do
    it "supports pattern matching on success" do
      result = case limiter.with_rate_limit { 42 }
               in [:success, value] then "got #{value}"
               in [:rate_limited, _] then "limited"
               end

      expect(result).to eq("got 42")
    end

    it "supports pattern matching on rate limited" do
      limiter.mark_request!

      result = case limiter.with_rate_limit { 42 }
               in [:success, _] then "got it"
               in [:rate_limited, event] then "retry in #{event.retry_after.round(2)}s"
               end

      expect(result).to match(/retry in \d+\.\d+s/)
    end
  end
end
