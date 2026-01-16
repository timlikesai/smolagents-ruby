# rubocop:disable Smolagents/NoSleep -- sleep intentional for testing parallel execution timing
require "spec_helper"

RSpec.describe Smolagents::Concerns::EarlyYield, :slow do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::EarlyYield

      def execute_tool_call(tool_call)
        # Simulate tool execution with configurable delays
        sleep(tool_call.arguments[:delay] || 0.1)
        Smolagents::ToolOutput.from_call(
          tool_call,
          output: tool_call.arguments[:output],
          observation: "Result: #{tool_call.arguments[:output]}",
          is_final: false
        )
      end
    end
  end

  let(:executor) { test_class.new }

  def make_tool_call(id:, output:, delay: 0.005)
    Smolagents::ToolCall.new(id:, name: "test_tool", arguments: { output:, delay: })
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
        slow_call = make_tool_call(id: "slow", output: "slow_result", delay: 0.02)
        fast_call = make_tool_call(id: "fast", output: "fast_result", delay: 0.001)

        result = executor.execute_with_early_yield([slow_call, fast_call]) do |r|
          r.output == "fast_result"
        end

        expect(result.early_result.output).to eq("fast_result")
        expect(result.early?).to be true
      end

      it "waits for all if no result passes quality check" do
        calls = [
          make_tool_call(id: "tc1", output: "bad1", delay: 0.002),
          make_tool_call(id: "tc2", output: "bad2", delay: 0.002)
        ]

        result = executor.execute_with_early_yield(calls) do |r|
          r.output == "good" # Nothing will match
        end

        expect(result.complete?).to be true
        expect(result.early_result).to be_nil
        expect(result.results.size).to eq(2)
      end

      it "collects remaining results when requested" do
        slow_call = make_tool_call(id: "slow", output: "slow_result", delay: 0.015)
        fast_call = make_tool_call(id: "fast", output: "fast_result", delay: 0.001)

        result = executor.execute_with_early_yield([slow_call, fast_call]) do |r|
          r.output == "fast_result"
        end

        # Early result available
        expect(result.early?).to be true
        expect(result.early_result.output).to eq("fast_result")

        # Collect remaining (blocks until slow completes)
        all_results = result.collect_remaining
        expect(all_results.size).to eq(2)
        expect(all_results.map(&:output)).to contain_exactly("slow_result", "fast_result")
      end
    end

    context "without quality predicate" do
      it "uses first result as early result" do
        calls = [
          make_tool_call(id: "tc1", output: "first", delay: 0.001),
          make_tool_call(id: "tc2", output: "second", delay: 0.01)
        ]

        result = executor.execute_with_early_yield(calls)

        # Should complete with first arriving result
        expect(result.results.map(&:output)).to include("first")
      end
    end
  end
end
# rubocop:enable Smolagents/NoSleep
