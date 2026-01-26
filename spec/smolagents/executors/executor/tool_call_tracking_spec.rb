require "spec_helper"

RSpec.describe Smolagents::Executors::Executor::ToolCallTracking do
  let(:tracking_class) do
    Class.new do
      include Smolagents::Executors::Executor::ToolCallTracking

      def initialize = initialize_tool_call_tracking
    end
  end

  let(:tracker) { tracking_class.new }

  describe "TrackedCall" do
    let(:tracked_call) do
      Smolagents::Executors::Executor::ToolCallTracking::TrackedCall.new(
        tool_name: "search",
        arguments: { query: "ruby" },
        result: %w[result1 result2],
        duration: 0.5,
        error: nil
      )
    end

    it "stores all attributes" do
      expect(tracked_call.tool_name).to eq("search")
      expect(tracked_call.arguments).to eq({ query: "ruby" })
      expect(tracked_call.result).to eq(%w[result1 result2])
      expect(tracked_call.duration).to eq(0.5)
      expect(tracked_call.error).to be_nil
    end

    describe "#success?" do
      it "returns true when error is nil" do
        expect(tracked_call.success?).to be true
      end

      it "returns false when error is present" do
        failed_call = tracked_call.with(error: "timeout")
        expect(failed_call.success?).to be false
      end
    end

    describe "#to_h" do
      it "converts to hash" do
        hash = tracked_call.to_h

        expect(hash).to eq({
                             tool_name: "search",
                             arguments: { query: "ruby" },
                             result: %w[result1 result2],
                             duration: 0.5,
                             error: nil
                           })
      end
    end
  end

  describe "#tool_calls" do
    it "returns empty array initially" do
      expect(tracker.tool_calls).to eq([])
    end

    it "initializes lazily" do
      new_tracker = tracking_class.new
      expect(new_tracker.tool_calls).to be_an(Array)
    end
  end

  describe "#clear_tool_calls" do
    it "resets tool_calls to empty array" do
      tracker.send(:record_tool_call,
                   tool_name: "test",
                   arguments: {},
                   result: "done",
                   duration: 0.1)

      expect(tracker.tool_calls.size).to eq(1)

      tracker.clear_tool_calls

      expect(tracker.tool_calls).to eq([])
    end
  end

  describe "#record_tool_call (private)" do
    it "adds TrackedCall to tool_calls" do
      tracker.send(:record_tool_call,
                   tool_name: "search",
                   arguments: { q: "test" },
                   result: "found",
                   duration: 0.25,
                   error: nil)

      expect(tracker.tool_calls.size).to eq(1)
      call = tracker.tool_calls.first
      expect(call.tool_name).to eq("search")
      expect(call.arguments).to eq({ q: "test" })
      expect(call.result).to eq("found")
      expect(call.duration).to eq(0.25)
    end

    it "records errors" do
      tracker.send(:record_tool_call,
                   tool_name: "failing_tool",
                   arguments: {},
                   result: nil,
                   duration: 0.1,
                   error: "connection failed")

      call = tracker.tool_calls.first
      expect(call.error).to eq("connection failed")
      expect(call.success?).to be false
    end

    it "accumulates multiple calls" do
      3.times do |i|
        tracker.send(:record_tool_call,
                     tool_name: "tool_#{i}",
                     arguments: { index: i },
                     result: i * 10,
                     duration: 0.1)
      end

      expect(tracker.tool_calls.size).to eq(3)
      expect(tracker.tool_calls.map(&:tool_name)).to eq(%w[tool_0 tool_1 tool_2])
    end
  end

  describe "#wrap_tools_for_tracking (private)" do
    let(:mock_tool) do
      instance_double(Smolagents::Tool, name: "mock_search", call: "result")
    end

    it "wraps tools in TrackedToolProxy" do
      tools = { "search" => mock_tool }

      wrapped = tracker.send(:wrap_tools_for_tracking, tools)

      expect(wrapped["search"]).to be_a(Smolagents::Executors::Executor::TrackedToolProxy)
    end

    it "preserves tool names as keys" do
      tools = { "search" => mock_tool, "web" => mock_tool }

      wrapped = tracker.send(:wrap_tools_for_tracking, tools)

      expect(wrapped.keys).to eq(%w[search web])
    end
  end
end

RSpec.describe Smolagents::Executors::Executor::TrackedToolProxy do
  let(:mock_tool) do
    Class.new do
      attr_reader :name

      def initialize
        @name = "test_tool"
      end

      def call(**kwargs) = kwargs[:value] * 2
    end.new
  end

  let(:tracker) do
    Class.new do
      include Smolagents::Executors::Executor::ToolCallTracking

      def initialize = initialize_tool_call_tracking
    end.new
  end

  let(:proxy) { described_class.new(mock_tool, tracker) }

  describe "#call" do
    it "returns a ToolFuture" do
      # Clear the thread-local batch to avoid interference
      Thread.current[:smolagents_future_batch] = []

      future = proxy.call(value: 21)

      # ToolFuture is a BasicObject subclass, so use duck typing
      expect(future._future?).to be true
      expect(future.tool_name).to eq("test_tool")
      expect(future.arguments).to eq({ value: 21 })
    end

    it "handles positional arguments" do
      Thread.current[:smolagents_future_batch] = []

      future = proxy.call("positional", "args")

      expect(future.arguments).to eq({ args: %w[positional args] })
    end
  end

  describe "method forwarding" do
    it "forwards other methods to underlying tool" do
      expect(proxy.name).to eq("test_tool")
    end

    it "responds to methods the tool responds to" do
      expect(proxy.respond_to?(:name)).to be true
      expect(proxy.respond_to?(:nonexistent)).to be false
    end
  end

  describe "execution and recording" do
    it "records successful tool calls when executed" do
      Thread.current[:smolagents_future_batch] = []
      future = proxy.call(value: 10)

      # Execute the future
      future._execute!

      expect(tracker.tool_calls.size).to eq(1)
      call = tracker.tool_calls.first
      expect(call.tool_name).to eq("test_tool")
      expect(call.result).to eq(20)
      expect(call.success?).to be true
    end

    it "records failed tool calls" do
      failing_tool = Class.new do
        def name = "failing"

        def call(**) = raise "tool error"
      end.new

      failing_proxy = described_class.new(failing_tool, tracker)
      Thread.current[:smolagents_future_batch] = []
      future = failing_proxy.call

      expect { future._execute! }.to raise_error("tool error")

      call = tracker.tool_calls.first
      expect(call.error).to eq("tool error")
      expect(call.success?).to be false
    end

    it "measures execution duration" do
      # Mock Process.clock_gettime to return controlled values
      start_time = 100.0
      end_time = 100.05 # 50ms elapsed

      call_count = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
        call_count += 1
        call_count == 1 ? start_time : end_time
      end

      slow_proxy = described_class.new(mock_tool, tracker)
      Thread.current[:smolagents_future_batch] = []
      future = slow_proxy.call(value: 10)

      future._execute!

      call = tracker.tool_calls.first
      expect(call.duration).to be_within(0.001).of(0.05)
    end
  end

  describe "tool name detection" do
    it "uses #name if available" do
      tool_with_name = Class.new do
        def name = "from_name"

        def call = nil
      end.new

      proxy = described_class.new(tool_with_name, tracker)
      Thread.current[:smolagents_future_batch] = []
      future = proxy.call

      expect(future.tool_name).to eq("from_name")
    end

    it "uses #tool_name if name not available" do
      tool_with_tool_name = Class.new do
        def tool_name = "from_tool_name"

        def call = nil
      end.new

      proxy = described_class.new(tool_with_tool_name, tracker)
      Thread.current[:smolagents_future_batch] = []
      future = proxy.call

      expect(future.tool_name).to eq("from_tool_name")
    end

    it "falls back to class name" do
      anonymous_tool = Class.new do
        def call = nil
      end.new

      proxy = described_class.new(anonymous_tool, tracker)
      Thread.current[:smolagents_future_batch] = []
      future = proxy.call

      # Anonymous class returns nil for name, so "unknown" is used
      expect(future.tool_name).to be_a(String)
    end
  end
end
