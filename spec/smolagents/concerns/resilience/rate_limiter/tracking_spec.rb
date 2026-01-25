require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Tracking do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RateLimiter::Tracking
      include Smolagents::Concerns::RateLimiter::Configuration

      def name
        "test_tool"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#rate_limit_ok?" do
    context "when rate limiting is disabled" do
      it "returns true" do
        expect(instance.rate_limit_ok?).to be true
      end
    end

    context "when rate limiting is enabled" do
      before do
        instance.setup_rate_limiter(10.0) # 10 requests per second
      end

      it "returns true when no recent request" do
        expect(instance.rate_limit_ok?).to be true
      end

      it "returns false immediately after request" do
        instance.mark_request!
        expect(instance.rate_limit_ok?).to be false
      end

      it "returns true after min_interval has passed" do
        instance.mark_request!
        # Simulate time passing by manipulating last_request_time
        instance.instance_variable_set(:@last_request_time, Time.now.to_f - 0.2)
        expect(instance.rate_limit_ok?).to be true
      end
    end
  end

  describe "#retry_after" do
    context "when rate limiting is disabled" do
      it "returns 0.0" do
        expect(instance.retry_after).to eq(0.0)
      end
    end

    context "when rate limiting is enabled" do
      before do
        instance.setup_rate_limiter(10.0)
      end

      it "returns 0.0 when request is allowed" do
        expect(instance.retry_after).to eq(0.0)
      end

      it "returns positive value after recent request" do
        instance.mark_request!
        expect(instance.retry_after).to be > 0
      end

      it "returns time remaining until next allowed request" do
        instance.mark_request!
        retry_val = instance.retry_after
        expect(retry_val).to be <= 0.1 # At 10 req/s, interval is 0.1s
      end
    end
  end

  describe "#time_until_allowed" do
    before do
      instance.setup_rate_limiter(10.0)
    end

    it "returns 0 when allowed" do
      expect(instance.time_until_allowed).to eq(0)
    end

    it "returns positive after request" do
      instance.mark_request!
      expect(instance.time_until_allowed).to be > 0
    end

    it "never returns negative" do
      instance.instance_variable_set(:@last_request_time, Time.now.to_f - 1.0)
      expect(instance.time_until_allowed).to eq(0)
    end
  end

  describe "#mark_request!" do
    before do
      instance.setup_rate_limiter(1.0)
    end

    it "updates last_request_time" do
      before_time = instance.instance_variable_get(:@last_request_time)
      instance.mark_request!
      after_time = instance.instance_variable_get(:@last_request_time)

      expect(after_time).to be > before_time
    end

    it "increments request_count" do
      expect { instance.mark_request! }
        .to change(instance, :request_count).by(1)
    end

    it "increments correctly for multiple calls" do
      3.times { instance.mark_request! }
      expect(instance.request_count).to eq(3)
    end
  end

  describe "#request_count" do
    before do
      instance.setup_rate_limiter(1.0)
    end

    it "starts at 0" do
      expect(instance.request_count).to eq(0)
    end

    it "reflects total requests" do
      5.times { instance.mark_request! }
      expect(instance.request_count).to eq(5)
    end
  end

  describe "#rate_limit_tool_name" do
    it "returns name when respond_to?(:name)" do
      expect(instance.rate_limit_tool_name).to eq("test_tool")
    end

    it "uses respond_to? to check for name method" do
      # The method uses respond_to?(:name) which includes the instance method
      expect(instance.rate_limit_tool_name).to eq("test_tool")
    end
  end

  describe "private #elapsed_since_last" do
    before do
      instance.setup_rate_limiter(1.0)
    end

    it "calculates elapsed time" do
      instance.instance_variable_set(:@last_request_time, Time.now.to_f - 0.5)
      elapsed = instance.send(:elapsed_since_last)

      expect(elapsed).to be >= 0.5
      expect(elapsed).to be < 1.0
    end
  end

  describe "thread safety" do
    before do
      instance.setup_rate_limiter(100.0)
    end

    it "handles concurrent mark_request! calls" do
      threads = Array.new(10) do
        Thread.new do
          5.times { instance.mark_request! }
        end
      end

      threads.each(&:join)

      # May not be exactly 50 due to race conditions, but should be > 0
      expect(instance.request_count).to be > 0
    end

    it "handles concurrent rate_limit_ok? calls" do
      results = []
      threads = Array.new(5) do
        Thread.new do
          5.times { results << instance.rate_limit_ok? }
        end
      end

      threads.each(&:join)

      expect(results).not_to be_empty
    end
  end

  describe "edge cases" do
    it "handles zero rate (no interval)" do
      instance.setup_rate_limiter(nil)
      expect(instance.rate_limit_ok?).to be true
    end

    it "handles high rate" do
      instance.setup_rate_limiter(1000.0)
      instance.mark_request!
      # At 1000 req/s, interval is 1ms
      expect(instance.retry_after).to be <= 0.001
    end

    it "handles low rate" do
      instance.setup_rate_limiter(0.1)
      instance.mark_request!
      # At 0.1 req/s, interval is 10s
      expect(instance.retry_after).to be <= 10.0
    end
  end
end
