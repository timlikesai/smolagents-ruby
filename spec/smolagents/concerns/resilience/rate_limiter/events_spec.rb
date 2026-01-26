require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Events do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RateLimiter::Events

      attr_reader :emitted_events
      attr_accessor :rate_limit_tool_name, :retry_after, :request_count, :limit_interval

      def initialize
        @emitted_events = []
        @rate_limit_tool_name = "test_tool"
        @retry_after = 1.0
        @request_count = 5
        @limit_interval = 60
      end

      def emit(event) = @emitted_events << event
    end
  end

  let(:instance) { test_class.new }

  describe "module inclusion" do
    it "includes Events::Emitter" do
      expect(test_class.ancestors).to include(Smolagents::Events::Emitter)
    end
  end

  describe "#rate_limit_event" do
    it "creates a RateLimitHit event" do
      event = instance.rate_limit_event

      expect(event).to be_a(Smolagents::Events::RateLimitHit)
    end

    it "includes tool_name in event" do
      event = instance.rate_limit_event

      expect(event.tool_name).to eq("test_tool")
    end

    it "includes retry_after in event" do
      instance.retry_after = 2.5
      event = instance.rate_limit_event

      expect(event.retry_after).to eq(2.5)
    end

    it "includes original_request when provided" do
      request = { query: "test" }
      event = instance.rate_limit_event(original_request: request)

      expect(event.original_request).to eq(request)
    end

    it "has nil original_request by default" do
      event = instance.rate_limit_event

      expect(event.original_request).to be_nil
    end
  end

  describe "#emit_rate_limit_violated" do
    it "emits a RateLimitViolated event" do
      instance.emit_rate_limit_violated

      expect(instance.emitted_events.size).to eq(1)
      expect(instance.emitted_events.first).to be_a(Smolagents::Events::RateLimitViolated)
    end

    it "includes tool_name in event" do
      instance.emit_rate_limit_violated

      expect(instance.emitted_events.first.tool_name).to eq("test_tool")
    end

    it "includes retry_after in event" do
      instance.retry_after = 3.0
      instance.emit_rate_limit_violated

      expect(instance.emitted_events.first.retry_after).to eq(3.0)
    end

    it "includes request_count in event" do
      instance.request_count = 10
      instance.emit_rate_limit_violated

      expect(instance.emitted_events.first.request_count).to eq(10)
    end

    it "includes limit_interval in event" do
      instance.limit_interval = 120
      instance.emit_rate_limit_violated

      expect(instance.emitted_events.first.limit_interval).to eq(120)
    end

    it "returns the emit result" do
      result = instance.emit_rate_limit_violated

      # emit returns an array containing the event
      expect(result).to be_an(Array)
      expect(result.first).to be_a(Smolagents::Events::RateLimitViolated)
    end
  end

  describe "multiple instances" do
    it "maintains separate event lists" do
      instance1 = test_class.new
      instance2 = test_class.new

      instance1.emit_rate_limit_violated
      instance2.emit_rate_limit_violated
      instance2.emit_rate_limit_violated

      expect(instance1.emitted_events.size).to eq(1)
      expect(instance2.emitted_events.size).to eq(2)
    end
  end
end
