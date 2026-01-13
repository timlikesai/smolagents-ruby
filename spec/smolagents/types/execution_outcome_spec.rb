require "spec_helper"

RSpec.describe Smolagents::Types::ExecutionOutcome do
  describe "base ExecutionOutcome" do
    describe "factory methods" do
      it "creates success outcome" do
        outcome = described_class.success("result", duration: 1.5, metadata: { test: true })

        expect(outcome.state).to eq(:success)
        expect(outcome.value).to eq("result")
        expect(outcome.error).to be_nil
        expect(outcome.duration).to eq(1.5)
        expect(outcome.metadata).to eq({ test: true })
      end

      it "creates final_answer outcome" do
        outcome = described_class.final_answer("answer", duration: 2.0)

        expect(outcome.state).to eq(:final_answer)
        expect(outcome.value).to eq("answer")
        expect(outcome.error).to be_nil
        expect(outcome.duration).to eq(2.0)
      end

      it "creates error outcome" do
        error = StandardError.new("boom")
        outcome = described_class.error(error, duration: 0.5)

        expect(outcome.state).to eq(:error)
        expect(outcome.value).to be_nil
        expect(outcome.error).to eq(error)
        expect(outcome.duration).to eq(0.5)
      end

      it "creates max_steps outcome" do
        outcome = described_class.max_steps(steps_taken: 10, duration: 5.0)

        expect(outcome.state).to eq(:max_steps_reached)
        expect(outcome.value).to be_nil
        expect(outcome.metadata[:steps_taken]).to eq(10)
        expect(outcome.duration).to eq(5.0)
      end

      it "creates timeout outcome" do
        outcome = described_class.timeout(duration: 30.0)

        expect(outcome.state).to eq(:timeout)
        expect(outcome.value).to be_nil
        expect(outcome.duration).to eq(30.0)
      end
    end

    describe "predicate methods" do
      it "success? returns true for success state" do
        outcome = described_class.success("result")
        expect(outcome.success?).to be true
        expect(outcome.error?).to be false
        expect(outcome.completed?).to be true
        expect(outcome.failed?).to be false
      end

      it "final_answer? returns true for final_answer state" do
        outcome = described_class.final_answer("answer")
        expect(outcome.final_answer?).to be true
        expect(outcome.success?).to be false
        expect(outcome.completed?).to be true
        expect(outcome.failed?).to be false
      end

      it "error? returns true for error state" do
        outcome = described_class.error(StandardError.new("boom"))
        expect(outcome.error?).to be true
        expect(outcome.success?).to be false
        expect(outcome.completed?).to be false
        expect(outcome.failed?).to be true
      end

      it "max_steps? returns true for max_steps_reached state" do
        outcome = described_class.max_steps(steps_taken: 10)
        expect(outcome.max_steps?).to be true
        expect(outcome.failed?).to be true
      end

      it "timeout? returns true for timeout state" do
        outcome = described_class.timeout
        expect(outcome.timeout?).to be true
        expect(outcome.failed?).to be true
      end
    end

    describe "#value!" do
      it "returns value for successful outcome" do
        outcome = described_class.success("result")
        expect(outcome.value!).to eq("result")
      end

      it "returns value for final_answer outcome" do
        outcome = described_class.final_answer("answer")
        expect(outcome.value!).to eq("answer")
      end

      it "raises error for error outcome" do
        error = StandardError.new("boom")
        outcome = described_class.error(error)

        expect { outcome.value! }.to raise_error(StandardError, "boom")
      end

      it "raises for failed outcomes" do
        outcome = described_class.max_steps(steps_taken: 10)

        expect { outcome.value! }.to raise_error(StandardError, /Operation failed/)
      end
    end

    describe "#to_event_payload" do
      it "includes base fields for success" do
        outcome = described_class.success("result", duration: 1.0, metadata: { key: "value" })
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:success)
        expect(payload[:duration]).to eq(1.0)
        expect(payload[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
        expect(payload[:metadata]).to eq({ key: "value" })
        expect(payload[:value]).to eq("result")
        expect(payload).not_to have_key(:error)
      end

      it "includes error details for error outcome" do
        error = ArgumentError.new("invalid arg")
        outcome = described_class.error(error, duration: 0.5)
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:error)
        expect(payload[:error]).to eq("ArgumentError")
        expect(payload[:error_message]).to eq("invalid arg")
        expect(payload).not_to have_key(:value)
      end
    end

    describe "pattern matching" do
      it "matches on success state and value" do
        outcome = described_class.success("result")

        matched = case outcome
                  in Smolagents::ExecutionOutcome[state: :success, value:]
                    "success: #{value}"
                  else
                    "no match"
                  end

        expect(matched).to eq("success: result")
      end

      it "matches on error state" do
        error = StandardError.new("boom")
        outcome = described_class.error(error)

        matched = case outcome
                  in Smolagents::ExecutionOutcome[state: :error, error:]
                    "error: #{error.message}"
                  else
                    "no match"
                  end

        expect(matched).to eq("error: boom")
      end
    end
  end

  describe Smolagents::ExecutorExecutionOutcome do
    let(:exec_result) { Smolagents::Executors::Executor::ExecutionResult.success(output: "42", logs: "computing...") }

    describe ".from_result" do
      it "creates outcome from successful ExecutionResult" do
        outcome = described_class.from_result(exec_result, duration: 1.5)

        expect(outcome.state).to eq(:success)
        expect(outcome.value).to eq("42")
        expect(outcome.error).to be_nil
        expect(outcome.duration).to eq(1.5)
        expect(outcome.result).to eq(exec_result)
      end

      it "creates outcome from final_answer ExecutionResult" do
        result = Smolagents::Executors::Executor::ExecutionResult.success(
          output: "answer",
          logs: "",
          is_final_answer: true
        )
        outcome = described_class.from_result(result, duration: 2.0)

        expect(outcome.state).to eq(:final_answer)
        expect(outcome.final_answer?).to be true
        expect(outcome.value).to eq("answer")
        expect(outcome.result.is_final_answer).to be true
      end

      it "creates outcome from failed ExecutionResult" do
        result = Smolagents::Executors::Executor::ExecutionResult.failure(error: "syntax error")
        outcome = described_class.from_result(result, duration: 0.5)

        expect(outcome.state).to eq(:error)
        expect(outcome.error?).to be true
        expect(outcome.error).to be_a(StandardError)
        expect(outcome.error.message).to eq("syntax error")
      end
    end

    describe "delegation to contained result" do
      it "delegates output to result" do
        outcome = described_class.from_result(exec_result)
        expect(outcome.output).to eq("42")
      end

      it "delegates logs to result" do
        outcome = described_class.from_result(exec_result)
        expect(outcome.logs).to eq("computing...")
      end
    end

    describe "#to_event_payload" do
      it "includes executor-specific fields" do
        outcome = described_class.from_result(exec_result, duration: 1.0)
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:success)
        expect(payload[:output]).to eq("42")
        expect(payload[:logs]).to eq("computing...")
        expect(payload[:duration]).to eq(1.0)
      end
    end

    describe "composition pattern validation" do
      it "outcome CONTAINS result, preserves all data" do
        outcome = described_class.from_result(exec_result, duration: 1.0)

        # Outcome adds state machine
        expect(outcome.success?).to be true
        expect(outcome.state).to eq(:success)

        # Result is contained and fully accessible
        expect(outcome.result).to eq(exec_result)
        expect(outcome.result.output).to eq("42")
        expect(outcome.result.logs).to eq("computing...")
        expect(outcome.result.success?).to be true

        # Delegation provides convenience
        expect(outcome.output).to eq(outcome.result.output)
        expect(outcome.logs).to eq(outcome.result.logs)
      end
    end
  end

  describe Smolagents::StepExecutionOutcome do
    let(:action_step) do
      Smolagents::ActionStep.new(
        step_number: 1,
        observations: "Found 3 results",
        tool_calls: [],
        action_output: "result",
        is_final_answer: false
      )
    end

    describe ".from_step" do
      it "creates outcome from ActionStep" do
        outcome = described_class.from_step(action_step, duration: 2.5)

        expect(outcome.state).to eq(:success)
        expect(outcome.value).to eq("result")
        expect(outcome.duration).to eq(2.5)
        expect(outcome.step).to eq(action_step)
      end

      it "creates final_answer outcome from final step" do
        final_step = Smolagents::ActionStep.new(
          step_number: 5,
          action_output: "final answer",
          is_final_answer: true
        )
        outcome = described_class.from_step(final_step)

        expect(outcome.state).to eq(:final_answer)
        expect(outcome.final_answer?).to be true
        expect(outcome.value).to eq("final answer")
      end

      it "creates error outcome from step with error" do
        error_step = Smolagents::ActionStep.new(
          step_number: 2,
          error: "tool failed"
        )
        outcome = described_class.from_step(error_step)

        expect(outcome.state).to eq(:error)
        expect(outcome.error?).to be true
        expect(outcome.error).to be_a(StandardError)
      end
    end

    describe "delegation to contained step" do
      it "delegates step fields" do
        outcome = described_class.from_step(action_step)

        expect(outcome.step_number).to eq(1)
        expect(outcome.observations).to eq("Found 3 results")
        expect(outcome.tool_calls).to eq([])
      end
    end

    describe "#to_event_payload" do
      it "includes step-specific fields" do
        outcome = described_class.from_step(action_step, duration: 2.0)
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:success)
        expect(payload[:step_number]).to eq(1)
        expect(payload[:observations]).to eq("Found 3 results")
        expect(payload[:tool_calls]).to eq([])
        expect(payload[:duration]).to eq(2.0)
      end
    end
  end

  describe Smolagents::AgentExecutionOutcome do
    let(:run_result) do
      Smolagents::RunResult.new(
        output: "final answer",
        state: :success,
        steps: [],
        token_usage: nil,
        timing: nil
      )
    end

    describe ".from_run_result" do
      it "creates outcome from RunResult" do
        outcome = described_class.from_run_result(run_result, task: "Calculate 2+2")

        expect(outcome.state).to eq(:success)
        expect(outcome.value).to eq("final answer")
        expect(outcome.run_result).to eq(run_result)
        expect(outcome.metadata[:task]).to eq("Calculate 2+2")
      end

      it "maps max_steps_reached state" do
        max_steps_result = Smolagents::RunResult.new(
          output: nil,
          state: :max_steps_reached,
          steps: [],
          token_usage: nil,
          timing: nil
        )
        outcome = described_class.from_run_result(max_steps_result)

        expect(outcome.state).to eq(:max_steps_reached)
        expect(outcome.max_steps?).to be true
      end

      it "includes error if provided" do
        error = RuntimeError.new("agent failed")
        outcome = described_class.from_run_result(run_result, error: error)

        expect(outcome.error).to eq(error)
      end
    end

    describe "delegation to contained run_result" do
      it "delegates to run result fields" do
        outcome = described_class.from_run_result(run_result)

        expect(outcome.output).to eq("final answer")
        expect(outcome.steps).to eq([])
        expect(outcome.token_usage).to be_nil
      end
    end

    describe "#to_event_payload" do
      it "includes agent-specific fields" do
        outcome = described_class.from_run_result(run_result, task: "test")
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:success)
        expect(payload[:output]).to eq("final answer")
        expect(payload[:steps_taken]).to eq(0)
      end
    end
  end

  describe Smolagents::ToolExecutionOutcome do
    describe "creation and predicates" do
      it "creates tool outcome with tool-specific fields" do
        outcome = described_class.new(
          state: :success,
          value: %w[result1 result2],
          error: nil,
          duration: 1.5,
          metadata: {},
          tool_name: "search",
          arguments: { query: "test" }
        )

        expect(outcome.success?).to be true
        expect(outcome.tool_name).to eq("search")
        expect(outcome.arguments).to eq({ query: "test" })
        expect(outcome.value).to eq(%w[result1 result2])
      end
    end

    describe "#to_event_payload" do
      it "includes tool-specific fields" do
        outcome = described_class.new(
          state: :success,
          value: "result",
          error: nil,
          duration: 0.5,
          metadata: {},
          tool_name: "calculator",
          arguments: { expression: "2+2" }
        )
        payload = outcome.to_event_payload

        expect(payload[:outcome]).to eq(:success)
        expect(payload[:tool_name]).to eq("calculator")
        expect(payload[:arguments]).to eq({ expression: "2+2" })
        expect(payload[:duration]).to eq(0.5)
        expect(payload[:value]).to eq("result")
      end
    end
  end
end
