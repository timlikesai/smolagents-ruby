require_relative "../../../lib/smolagents/executors/fiber_execution"

RSpec.describe Smolagents::Executors::FiberExecution do
  describe "RETRIEVAL_TOOLS" do
    it "contains expected tool names" do
      expected = %w[search web fetch wikipedia http api query]
      expected.each do |tool|
        expect(described_class::RETRIEVAL_TOOLS).to include(tool)
      end
    end

    it "includes search engine names" do
      expect(described_class::RETRIEVAL_TOOLS).to include("duckduckgo", "google", "bing", "searxng")
    end
  end

  describe ".in_fiber?" do
    it "returns false by default" do
      expect(described_class.in_fiber?).to be false
    end

    it "returns true when thread local is set" do
      Thread.current[:smolagents_in_code_fiber] = true
      expect(described_class.in_fiber?).to be true
      Thread.current[:smolagents_in_code_fiber] = nil
    end

    it "respects thread local isolation" do
      Thread.current[:smolagents_in_code_fiber] = true

      result = nil
      thread = Thread.new do
        result = described_class.in_fiber?
      end
      thread.join

      expect(result).to be false

      Thread.current[:smolagents_in_code_fiber] = nil
    end
  end

  describe ".yield_tool" do
    it "returns result when not in fiber" do
      result = described_class.yield_tool(
        tool_name: "search",
        arguments: { query: "Ruby" },
        result: ["Ruby 3.0"],
        duration: 0.5
      )

      expect(result).to eq(["Ruby 3.0"])
    end

    it "yields ToolYield when in fiber" do
      # Ruby 3.0+ Thread.current[:key] is fiber-local, must set inside fiber
      fiber = Fiber.new do
        Thread.current[:smolagents_in_code_fiber] = true
        described_class.yield_tool(
          tool_name: "search",
          arguments: { query: "Ruby" },
          result: ["Ruby 3.0"],
          duration: 0.5
        )
      ensure
        Thread.current[:smolagents_in_code_fiber] = nil
      end

      yield_result = fiber.resume
      expect(yield_result).to be_a(described_class::ToolYield)
      expect(yield_result.tool_name).to eq("search")
      expect(yield_result.result).to eq(["Ruby 3.0"])
    end

    it "passes through result after fiber resumes" do
      # Ruby 3.0+ Thread.current[:key] is fiber-local, must set inside fiber
      fiber = Fiber.new do
        Thread.current[:smolagents_in_code_fiber] = true
        result = described_class.yield_tool(
          tool_name: "search",
          arguments: {},
          result: ["data"],
          duration: 0.1
        )

        "processed_#{result[0]}"
      ensure
        Thread.current[:smolagents_in_code_fiber] = nil
      end

      _yield = fiber.resume
      final_result = fiber.resume
      expect(final_result).to eq("processed_data")
    end
  end

  describe "ToolYield" do
    let(:tool_yield) do
      described_class::ToolYield.new(
        tool_name: "search",
        arguments: { query: "Ruby" },
        result: ["Ruby 3.0"],
        duration: 0.5
      )
    end

    describe "#retrieval?" do
      it "returns true for retrieval tools" do
        %w[search web fetch wikipedia].each do |tool|
          ty = described_class::ToolYield.new(
            tool_name: tool,
            arguments: {},
            result: [],
            duration: 0.1
          )
          expect(ty.retrieval?).to be true
        end
      end

      it "returns false for non-retrieval tools" do
        %w[calculate format send_email].each do |tool|
          ty = described_class::ToolYield.new(
            tool_name: tool,
            arguments: {},
            result: "data",
            duration: 0.1
          )
          expect(ty.retrieval?).to be false
        end
      end

      it "is case insensitive" do
        ty = described_class::ToolYield.new(
          tool_name: "SEARCH",
          arguments: {},
          result: [],
          duration: 0.1
        )
        expect(ty.retrieval?).to be true
      end
    end

    describe "#final?" do
      it "returns true for final_answer" do
        ty = described_class::ToolYield.new(
          tool_name: "final_answer",
          arguments: { answer: "42" },
          result: "42",
          duration: 0.0
        )
        expect(ty.final?).to be true
      end

      it "returns false for other tools" do
        expect(tool_yield.final?).to be false
      end

      it "is case sensitive" do
        ty = described_class::ToolYield.new(
          tool_name: "FINAL_ANSWER",
          arguments: {},
          result: "data",
          duration: 0.0
        )
        expect(ty.final?).to be false
      end
    end

    describe "#subagent?" do
      it "returns true for agent_* tool names" do
        ty = described_class::ToolYield.new(
          tool_name: "agent_summarizer",
          arguments: {},
          result: "summary",
          duration: 0.1
        )
        expect(ty.subagent?).to be true
      end

      it "returns true for RunResult outcomes" do
        # Simulate a RunResult from running a subagent
        # subagent? checks: tool_name starts with "agent_" OR result.is_a?(RunResult)
        # Since tool_name is "subagent" (not "agent_*"), we need result to be a RunResult
        run_result = double("RunResult")
        allow(run_result).to receive(:is_a?).with(Smolagents::RunResult).and_return(true)

        ty = described_class::ToolYield.new(
          tool_name: "subagent",
          arguments: {},
          result: run_result,
          duration: 0.1
        )
        expect(ty.subagent?).to be true
      end

      it "returns false for regular tools" do
        expect(tool_yield.subagent?).to be false
      end
    end

    describe "Data.define behavior" do
      it "is immutable" do
        # Data.define objects don't have setter methods
        expect { tool_yield.tool_name = "other" }.to raise_error(NoMethodError)
      end

      it "is a Data instance" do
        expect(tool_yield).to be_a(Data)
      end
    end
  end

  describe "ExecutionState" do
    describe ".running" do
      it "creates running state" do
        batch = double("Batch")
        state = described_class::ExecutionState.running([], batch)

        expect(state.status).to eq(:running)
        expect(state.batch).to eq(batch)
        expect(state.output).to be_nil
        expect(state.error).to be_nil
        expect(state.running?).to be true
        expect(state.completed?).to be false
        expect(state.failed?).to be false
      end
    end

    describe ".completed" do
      it "creates completed state" do
        output = "final answer"
        state = described_class::ExecutionState.completed(output, [])

        expect(state.status).to eq(:completed)
        expect(state.output).to eq("final answer")
        expect(state.batch).to be_nil
        expect(state.error).to be_nil
        expect(state.completed?).to be true
        expect(state.running?).to be false
        expect(state.failed?).to be false
      end
    end

    describe ".failed" do
      it "creates failed state" do
        error = "execution error"
        state = described_class::ExecutionState.failed(error, [])

        expect(state.status).to eq(:failed)
        expect(state.error).to eq("execution error")
        expect(state.batch).to be_nil
        expect(state.output).to be_nil
        expect(state.failed?).to be true
        expect(state.running?).to be false
        expect(state.completed?).to be false
      end
    end

    describe "#all_futures" do
      it "collects futures from all batches" do
        future1 = double("Future1")
        future2 = double("Future2")
        future3 = double("Future3")

        batch1 = double("Batch1", futures: [future1, future2])
        batch2 = double("Batch2", futures: [future3])

        state = described_class::ExecutionState.completed("done", [batch1, batch2])
        expect(state.all_futures).to eq([future1, future2, future3])
      end

      it "returns empty array with no batches" do
        state = described_class::ExecutionState.completed("done", [])
        expect(state.all_futures).to eq([])
      end
    end

    describe "#retrieval_batch?" do
      it "returns true when current batch has retrieval tools" do
        retrieval_future = double("Future", tool_name: "search")
        batch = double("Batch", futures: [retrieval_future])
        state = described_class::ExecutionState.running([], batch)

        expect(state.retrieval_batch?).to be true
      end

      it "returns false when current batch has no retrieval tools" do
        calculate_future = double("Future", tool_name: "calculate")
        batch = double("Batch", futures: [calculate_future])
        state = described_class::ExecutionState.running([], batch)

        expect(state.retrieval_batch?).to be false
      end

      it "returns false when no batch" do
        state = described_class::ExecutionState.completed("done", [])
        # Returns nil when no batch, which is falsy
        expect(state).not_to be_retrieval_batch
      end
    end

    describe "#final_answer_batch?" do
      it "returns true when batch has final_answer" do
        final_future = double("Future", tool_name: "final_answer")
        batch = double("Batch", futures: [final_future])
        state = described_class::ExecutionState.running([], batch)

        expect(state.final_answer_batch?).to be true
      end

      it "returns false when batch doesn't have final_answer" do
        search_future = double("Future", tool_name: "search")
        batch = double("Batch", futures: [search_future])
        state = described_class::ExecutionState.running([], batch)

        expect(state.final_answer_batch?).to be false
      end

      it "returns false when no batch" do
        state = described_class::ExecutionState.completed("done", [])
        # Returns nil when no batch, which is falsy
        expect(state).not_to be_final_answer_batch
      end
    end

    describe "state predicates" do
      it "running? is accurate" do
        running_state = described_class::ExecutionState.running([], double)
        expect(running_state.running?).to be true
        expect(running_state.completed?).to be false
        expect(running_state.failed?).to be false
      end

      it "completed? is accurate" do
        completed_state = described_class::ExecutionState.completed("result", [])
        expect(completed_state.completed?).to be true
        expect(completed_state.running?).to be false
        expect(completed_state.failed?).to be false
      end

      it "failed? is accurate" do
        failed_state = described_class::ExecutionState.failed("error", [])
        expect(failed_state.failed?).to be true
        expect(failed_state.running?).to be false
        expect(failed_state.completed?).to be false
      end
    end

    describe "Data.define behavior" do
      it "is immutable" do
        state = described_class::ExecutionState.completed("done", [])
        # Data.define objects don't have setter methods
        expect { state.output = "other" }.to raise_error(NoMethodError)
      end
    end
  end

  describe "module usage patterns" do
    it "can be included in executor" do
      # The module's class methods can be called on the module itself
      # Verify it doesn't raise when included
      test_class = Class.new do
        include Smolagents::Executors::FiberExecution
      end

      # Should be able to create instance without error
      expect(test_class.new).not_to be_nil
    end

    it "supports setting fiber context" do
      Thread.current[:smolagents_in_code_fiber] = true
      expect(described_class.in_fiber?).to be true
      Thread.current[:smolagents_in_code_fiber] = nil
    end
  end
end
