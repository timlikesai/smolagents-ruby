require "spec_helper"

RSpec.describe Smolagents::Concerns::EarlyYield do
  # Use Thread::Queue for coordination instead of sleep.
  # Each tool call waits for a signal before completing.
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::EarlyYield

      attr_reader :queues

      def initialize
        @queues = {}
      end

      def execute_tool_call(tool_call)
        id = tool_call.id

        # Create a queue for this call if signaling is enabled
        if tool_call.arguments[:wait_for_signal]
          @queues[id] = Thread::Queue.new
          @queues[id].pop # Wait for signal
        end

        Smolagents::ToolOutput.from_call(
          tool_call,
          output: tool_call.arguments[:output],
          observation: "Result: #{tool_call.arguments[:output]}",
          is_final: false
        )
      end

      # Signal a tool call to complete
      def signal(id)
        @queues[id]&.push(:go)
      end
    end
  end

  let(:executor) { test_class.new }

  def make_tool_call(id:, output:, wait_for_signal: false)
    Smolagents::ToolCall.new(id:, name: "test_tool", arguments: { output:, wait_for_signal: })
  end

  describe "#execute_with_early_yield" do
    context "with single tool call" do
      it "executes directly without parallel overhead" do
        tool_call = make_tool_call(id: "tc1", output: "result")
        result = executor.execute_with_early_yield([tool_call]) { true }

        expect(result.results.size).to eq(1)
        expect(result.early_result.output).to eq("result")
        expect(result.complete?).to be true
        expect(result.pending_count).to eq(0)
      end
    end

    context "with multiple tool calls" do
      it "yields early when quality predicate passes" do
        # Fast call completes immediately, slow call waits for signal
        slow_call = make_tool_call(id: "slow", output: "slow_result", wait_for_signal: true)
        fast_call = make_tool_call(id: "fast", output: "fast_result", wait_for_signal: false)

        # Start execution in a thread
        result_queue = Thread::Queue.new
        Thread.new do
          result = executor.execute_with_early_yield([slow_call, fast_call]) do |r|
            r.output == "fast_result"
          end
          result_queue.push(result)
        end

        # Fast result should be available before slow call completes
        result = result_queue.pop
        expect(result.early_result.output).to eq("fast_result")
        expect(result.early?).to be true

        # Now signal slow call to complete
        executor.signal("slow")
      end

      it "waits for all if no result passes quality check" do
        calls = [
          make_tool_call(id: "tc1", output: "bad1"),
          make_tool_call(id: "tc2", output: "bad2")
        ]

        result = executor.execute_with_early_yield(calls) do |r|
          r.output == "good" # Nothing will match
        end

        expect(result.complete?).to be true
        expect(result.early_result).to be_nil
        expect(result.results.size).to eq(2)
      end

      it "collects remaining results when requested" do
        # Fast call completes immediately, slow call waits for signal
        slow_call = make_tool_call(id: "slow", output: "slow_result", wait_for_signal: true)
        fast_call = make_tool_call(id: "fast", output: "fast_result", wait_for_signal: false)

        # Start execution in a background thread
        result_holder = []
        execution_thread = Thread.new do
          result = executor.execute_with_early_yield([slow_call, fast_call]) do |r|
            r.output == "fast_result"
          end
          result_holder << result
        end

        # Wait for execution to start and process fast call
        execution_thread.join(0.1)

        # Now signal slow call to complete
        executor.signal("slow")

        # Wait for full execution
        execution_thread.join

        result = result_holder.first
        expect(result.early?).to be true
        expect(result.early_result.output).to eq("fast_result")

        # Collect remaining
        all_results = result.collect_remaining
        expect(all_results.size).to eq(2)
        expect(all_results.map(&:output)).to contain_exactly("slow_result", "fast_result")
      end
    end

    context "without quality predicate" do
      it "uses first result as early result" do
        calls = [
          make_tool_call(id: "tc1", output: "first"),
          make_tool_call(id: "tc2", output: "second")
        ]

        result = executor.execute_with_early_yield(calls)

        # Should complete with results
        expect(result.results.map(&:output)).to include("first")
      end
    end
  end
end
