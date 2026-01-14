require "smolagents/concerns/async_tools"

RSpec.describe Smolagents::Concerns::AsyncTools do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::AsyncTools

      attr_accessor :tools, :max_tool_threads

      def initialize
        @tools = {}
        @max_tool_threads = 4
      end

      def execute_tool_call(tool_call)
        tool = @tools[tool_call.name]
        raise "Unknown tool: #{tool_call.name}" unless tool

        result = tool.call(tool_call.arguments)
        Smolagents::ToolOutput.new(
          id: tool_call.id,
          output: result,
          is_final_answer: tool_call.name == "final_answer",
          observation: "#{tool_call.name}: #{result}",
          tool_call:
        )
      end

      def execute_tool_calls_parallel(tool_calls)
        tool_calls.map { |tc| execute_tool_call(tc) }
      end
    end
  end

  let(:instance) { test_class.new }

  let(:mock_tool) do
    tool = double("tool")
    allow(tool).to receive(:call) { |args| "result: #{args}" }
    tool
  end

  let(:slow_tool) do
    tool = double("slow_tool")
    allow(tool).to receive(:call) do |args|
      "slow result: #{args}"
    end
    tool
  end

  before do
    instance.tools = {
      "test_tool" => mock_tool,
      "slow_tool" => slow_tool
    }
  end

  describe Smolagents::Concerns::AsyncTools::AsyncResult do
    describe "#success?" do
      it "returns true when error is nil" do
        result = described_class.new(index: 0, value: "test", error: nil)
        expect(result.success?).to be true
      end

      it "returns false when error is present" do
        result = described_class.new(index: 0, value: nil, error: StandardError.new("test"))
        expect(result.success?).to be false
      end
    end

    describe "#failure?" do
      it "returns false when error is nil" do
        result = described_class.new(index: 0, value: "test", error: nil)
        expect(result.failure?).to be false
      end

      it "returns true when error is present" do
        result = described_class.new(index: 0, value: nil, error: StandardError.new("test"))
        expect(result.failure?).to be true
      end
    end

    it "supports pattern matching" do
      result = described_class.new(index: 0, value: "test", error: nil)

      matched = case result
                in Smolagents::Concerns::AsyncTools::AsyncResult[value:, error: nil]
                  value
                else
                  "no match"
                end

      expect(matched).to eq("test")
    end
  end

  describe "#execute_tool_calls_async" do
    let(:tool_call_1) { Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 1 }, id: "tc_1") }
    let(:tool_call_2) { Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 2 }, id: "tc_2") }

    context "with single tool call" do
      it "returns result directly without async" do
        results = instance.execute_tool_calls_async([tool_call_1])

        expect(results.size).to eq(1)
        expect(results.first).to be_a(Smolagents::ToolOutput)
        expect(results.first.id).to eq("tc_1")
      end
    end

    context "with multiple tool calls and no scheduler" do
      before do
        allow(Fiber).to receive(:scheduler).and_return(nil)
      end

      it "falls back to parallel execution" do
        results = instance.execute_tool_calls_async([tool_call_1, tool_call_2])

        expect(results.size).to eq(2)
        expect(results.map(&:id)).to eq(%w[tc_1 tc_2])
      end

      it "preserves order of results" do
        results = instance.execute_tool_calls_async([tool_call_1, tool_call_2])

        expect(results[0].output).to include("result:")
        expect(results[0].output).to include("1")
        expect(results[1].output).to include("result:")
        expect(results[1].output).to include("2")
      end
    end

    context "with fiber scheduler available" do
      let(:mock_scheduler) do
        scheduler = double("scheduler")
        allow(scheduler).to receive(:run)
        allow(scheduler).to receive(:respond_to?).with(:run).and_return(true)
        scheduler
      end

      let(:mock_fiber) do
        fiber = double("fiber")
        allow(fiber).to receive(:respond_to?).with(:alive?).and_return(true)
        allow(fiber).to receive(:alive?).and_return(false)
        fiber
      end

      before do
        allow(Fiber).to receive(:scheduler).and_return(mock_scheduler)
      end

      it "uses fiber-based execution" do
        schedule_call_count = 0

        # Mock Fiber.schedule to execute the block immediately
        allow(Fiber).to receive(:schedule) do |&block|
          schedule_call_count += 1
          block.call
          mock_fiber
        end

        results = instance.execute_tool_calls_async([tool_call_1, tool_call_2])

        expect(schedule_call_count).to eq(2)
        expect(results.size).to eq(2)
        expect(results.all?(Smolagents::ToolOutput)).to be true
      end
    end
  end

  describe "#fiber_scheduler_available?" do
    context "when no scheduler is set" do
      before do
        allow(Fiber).to receive(:scheduler).and_return(nil)
      end

      it "returns false" do
        expect(instance.send(:fiber_scheduler_available?)).to be false
      end
    end

    context "when scheduler is set but does not respond to run" do
      let(:incomplete_scheduler) { double("incomplete_scheduler") }

      before do
        allow(Fiber).to receive(:scheduler).and_return(incomplete_scheduler)
        allow(incomplete_scheduler).to receive(:respond_to?).with(:run).and_return(false)
      end

      it "returns false" do
        expect(instance.send(:fiber_scheduler_available?)).to be false
      end
    end

    context "when valid scheduler is set" do
      let(:valid_scheduler) do
        scheduler = double("valid_scheduler")
        allow(scheduler).to receive(:respond_to?).with(:run).and_return(true)
        scheduler
      end

      before do
        allow(Fiber).to receive(:scheduler).and_return(valid_scheduler)
      end

      it "returns true" do
        expect(instance.send(:fiber_scheduler_available?)).to be true
      end
    end
  end

  describe "#process_async_results" do
    it "extracts values from successful AsyncResults" do
      tool_output = Smolagents::ToolOutput.new(
        id: "tc_1",
        output: "test",
        is_final_answer: false,
        observation: "test",
        tool_call: nil
      )
      async_result = Smolagents::Concerns::AsyncTools::AsyncResult.new(
        index: 0,
        value: tool_output,
        error: nil
      )

      results = instance.send(:process_async_results, [async_result])

      expect(results.size).to eq(1)
      expect(results.first).to eq(tool_output)
    end

    it "builds error output for failed AsyncResults" do
      error = StandardError.new("tool failed")
      async_result = Smolagents::Concerns::AsyncTools::AsyncResult.new(
        index: 0,
        value: nil,
        error:
      )

      results = instance.send(:process_async_results, [async_result])

      expect(results.size).to eq(1)
      expect(results.first.observation).to include("Async execution error")
      expect(results.first.observation).to include("tool failed")
    end

    it "passes through ToolOutput objects directly" do
      tool_output = Smolagents::ToolOutput.new(
        id: "tc_1",
        output: "test",
        is_final_answer: false,
        observation: "test",
        tool_call: nil
      )

      results = instance.send(:process_async_results, [tool_output])

      expect(results.first).to eq(tool_output)
    end

    it "raises AsyncExecutionError for unexpected result types" do
      expect do
        instance.send(:process_async_results, ["unexpected string"])
      end.to raise_error(Smolagents::Concerns::AsyncExecutionError, /Unexpected result type/)
    end
  end

  describe "#build_error_output" do
    it "creates ToolOutput with error information" do
      error = StandardError.new("something went wrong")

      output = instance.send(:build_error_output, 5, error)

      expect(output).to be_a(Smolagents::ToolOutput)
      expect(output.id).to eq("async_error_5")
      expect(output.output).to be_nil
      expect(output.is_final_answer).to be false
      expect(output.observation).to include("something went wrong")
      expect(output.tool_call).to be_nil
    end
  end

  describe "integration with tool execution" do
    let(:tool_calls) do
      [
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 1 }, id: "tc_1"),
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 2 }, id: "tc_2"),
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 3 }, id: "tc_3")
      ]
    end

    context "without fiber scheduler" do
      before do
        allow(Fiber).to receive(:scheduler).and_return(nil)
      end

      it "executes all tool calls and returns results in order" do
        results = instance.execute_tool_calls_async(tool_calls)

        expect(results.size).to eq(3)
        expect(results.map(&:id)).to eq(%w[tc_1 tc_2 tc_3])
        expect(results.all?(Smolagents::ToolOutput)).to be true
      end
    end

    context "with error in one tool call" do
      let(:failing_tool) do
        tool = double("failing_tool")
        allow(tool).to receive(:call).and_raise(StandardError, "tool error")
        tool
      end

      before do
        instance.tools["failing_tool"] = failing_tool
        allow(Fiber).to receive(:scheduler).and_return(nil)
      end

      it "handles errors gracefully in synchronous fallback" do
        tool_calls_with_failure = [
          Smolagents::ToolCall.new(name: "test_tool", arguments: {}, id: "tc_1"),
          Smolagents::ToolCall.new(name: "failing_tool", arguments: {}, id: "tc_2")
        ]

        expect do
          instance.execute_tool_calls_async(tool_calls_with_failure)
        end.to raise_error(StandardError, "tool error")
      end
    end
  end

  describe Smolagents::Concerns::AsyncExecutionError do
    it "is a subclass of StandardError" do
      expect(described_class.superclass).to eq(StandardError)
    end

    it "can be raised with a message" do
      expect do
        raise described_class, "async error occurred"
      end.to raise_error(described_class, "async error occurred")
    end
  end
end
