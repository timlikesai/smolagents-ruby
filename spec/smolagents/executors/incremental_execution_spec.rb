require "spec_helper"

RSpec.describe Smolagents::Executors::IncrementalExecution do
  # Create a test executor that includes the concern
  let(:executor_class) do
    Class.new do
      include Smolagents::Executors::IncrementalExecution

      attr_accessor :sandbox_result, :output_buffer

      def initialize
        @output_buffer = StringIO.new
      end

      # rubocop:disable Security/Eval -- test stub simulates sandbox evaluation
      def execute_in_sandbox(code) = @sandbox_result || eval(code)
      # rubocop:enable Security/Eval

      def execute(code, language:) = build_result(execute_in_sandbox(code), captured_logs)

      def build_result(output, logs, error: nil, is_final: false)
        Smolagents::Executors::ExecutionResult.new(
          output:, logs:, error:, final_answer: is_final
        )
      end
    end
  end

  let(:executor) { executor_class.new }

  describe ".in_fiber_context?" do
    it "returns false when not in fiber execution" do
      expect(described_class.in_fiber_context?).to be false
    end

    it "returns true when set via fiber_context=" do
      described_class.fiber_context = true
      expect(described_class.in_fiber_context?).to be true
    ensure
      described_class.fiber_context = false
    end

    it "is thread-local" do
      described_class.fiber_context = true
      thread_value = Thread.new { described_class.in_fiber_context? }.value
      expect(thread_value).to be false
    ensure
      described_class.fiber_context = false
    end
  end

  describe "#execute_incrementally" do
    context "without a block" do
      it "falls back to non-incremental execution" do
        result = executor.execute_incrementally("1 + 1")
        expect(result.output).to eq(2)
      end
    end

    context "with a block" do
      it "executes simple code and returns result" do
        result = executor.execute_incrementally("42") { |_pause| :continue }
        expect(result.output).to eq(42)
      end

      it "captures output in logs" do
        executor.output_buffer = StringIO.new("captured output")
        result = executor.execute_incrementally("'done'") { |_pause| :continue }
        expect(result.logs).to eq("captured output")
      end
    end

    context "with ToolPause yields" do
      let(:pause) do
        Smolagents::Executors::ToolPause.new(
          tool_name: "search",
          arguments: {},
          result: "search results",
          duration: 0.1
        )
      end

      it "yields each ToolPause to the block" do
        yielded_pauses = []
        executor.sandbox_result = pause

        # Override to return pause then complete
        fiber_called = false
        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            unless fiber_called
              fiber_called = true
              Fiber.yield(pause)
            end
            "final result"
          end
        )

        executor.execute_incrementally("code") do |p|
          yielded_pauses << p
          :continue
        end

        expect(yielded_pauses).to eq([pause])
      end

      it "stops execution when block returns :stop" do
        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            Fiber.yield(pause)
            raise "Should not reach here"
          end
        )

        result = executor.execute_incrementally("code") { |_p| :stop }
        expect(result.output).to eq("search results")
        expect(result.final_answer).to be false
      end

      it "continues execution when block returns :continue" do
        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            Fiber.yield(pause)
            "completed"
          end
        )

        result = executor.execute_incrementally("code") { |_p| :continue }
        expect(result.output).to eq("completed")
      end
    end

    context "with FinalAnswerException" do
      it "catches FinalAnswerException and returns final result" do
        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            raise Smolagents::FinalAnswerException, "final answer"
          end
        )

        result = executor.execute_incrementally("code") { |_p| :continue }
        expect(result.output).to eq("final answer")
        expect(result.final_answer).to be true
      end
    end

    context "with errors" do
      it "catches StandardError and returns error result" do
        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            raise ArgumentError, "test error"
          end
        )

        result = executor.execute_incrementally("code") { |_p| :continue }
        expect(result.error).to eq("ArgumentError: test error")
      end
    end

    context "with multiple pauses" do
      it "handles multiple sequential pauses" do
        pause1 = Smolagents::Executors::ToolPause.new(tool_name: "tool1", arguments: {}, result: "r1", duration: 0.1)
        pause2 = Smolagents::Executors::ToolPause.new(tool_name: "tool2", arguments: {}, result: "r2", duration: 0.1)

        allow(executor).to receive(:create_execution_fiber).and_return(
          Fiber.new do
            Fiber.yield(pause1)
            Fiber.yield(pause2)
            "done"
          end
        )

        pauses = []
        result = executor.execute_incrementally("code") do |p|
          pauses << p.tool_name
          :continue
        end

        expect(pauses).to eq(%w[tool1 tool2])
        expect(result.output).to eq("done")
      end
    end
  end

  describe "#create_execution_fiber" do
    it "sets fiber context during execution" do
      context_during = nil
      allow(executor).to receive(:execute_in_sandbox) do
        context_during = described_class.in_fiber_context?
        "result"
      end

      fiber = executor.send(:create_execution_fiber, "code")
      fiber.resume

      expect(context_during).to be true
    end

    it "clears fiber context after execution" do
      allow(executor).to receive(:execute_in_sandbox).and_return("result")

      fiber = executor.send(:create_execution_fiber, "code")
      fiber.resume

      expect(described_class.in_fiber_context?).to be false
    end

    it "clears fiber context even on error" do
      allow(executor).to receive(:execute_in_sandbox).and_raise(RuntimeError, "boom")

      fiber = executor.send(:create_execution_fiber, "code")
      expect { fiber.resume }.to raise_error(RuntimeError, "boom")

      expect(described_class.in_fiber_context?).to be false
    end
  end
end
