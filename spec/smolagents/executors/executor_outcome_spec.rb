require "spec_helper"

RSpec.describe "Executor ExecutionOutcome Integration" do
  let(:executor) { Smolagents::Executors::LocalRuby.new }

  describe "#execute_with_outcome" do
    context "successful execution" do
      it "returns ExecutorExecutionOutcome with success state" do
        outcome = executor.execute_with_outcome("2 + 2", language: :ruby)

        expect(outcome).to be_a(Smolagents::ExecutorExecutionOutcome)
        expect(outcome.success?).to be true
        expect(outcome.state).to eq(:success)
        expect(outcome.value).to eq(4)
        expect(outcome.duration).to be > 0
      end

      it "contains ExecutionResult in result field (composition)" do
        outcome = executor.execute_with_outcome("'hello'.upcase", language: :ruby)

        expect(outcome.result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
        expect(outcome.result.success?).to be true
        expect(outcome.result.output).to eq("HELLO")
        expect(outcome.output).to eq("HELLO") # Delegates to result
      end

      it "includes logs from execution" do
        code = <<~RUBY
          puts "debug message"
          42
        RUBY

        outcome = executor.execute_with_outcome(code, language: :ruby)

        expect(outcome.result.logs).to include("debug message")
        expect(outcome.logs).to include("debug message") # Delegates to result
      end
    end

    context "execution with final_answer" do
      it "returns ExecutorExecutionOutcome with final_answer state (positional arg)" do
        executor.send_tools("final_answer" => Smolagents::Tools::FinalAnswerTool.new)

        outcome = executor.execute_with_outcome(
          "final_answer('The answer is 42')",
          language: :ruby
        )

        expect(outcome).to be_a(Smolagents::ExecutorExecutionOutcome)
        expect(outcome.final_answer?).to be true
        expect(outcome.state).to eq(:final_answer)
        expect(outcome.value).to eq("The answer is 42")
        expect(outcome.result.is_final_answer).to be true
      end

      it "returns ExecutorExecutionOutcome with final_answer state (keyword arg)" do
        executor.send_tools("final_answer" => Smolagents::Tools::FinalAnswerTool.new)

        outcome = executor.execute_with_outcome(
          "final_answer(answer: 'With keyword')",
          language: :ruby
        )

        expect(outcome).to be_a(Smolagents::ExecutorExecutionOutcome)
        expect(outcome.final_answer?).to be true
        expect(outcome.state).to eq(:final_answer)
        expect(outcome.value).to eq("With keyword")
        expect(outcome.result.is_final_answer).to be true
      end
    end

    context "execution with error" do
      it "returns ExecutorExecutionOutcome with error state" do
        outcome = executor.execute_with_outcome("1 / 0", language: :ruby)

        expect(outcome).to be_a(Smolagents::ExecutorExecutionOutcome)
        expect(outcome.error?).to be true
        expect(outcome.state).to eq(:error)
        expect(outcome.error).to be_a(StandardError)
        expect(outcome.result.failure?).to be true
      end
    end

    context "pattern matching on outcome" do
      it "allows pattern matching on success state" do
        outcome = executor.execute_with_outcome("123", language: :ruby)

        matched = case outcome
                  in Smolagents::ExecutorExecutionOutcome[state: :success, value:]
                    "matched success: #{value}"
                  else
                    "no match"
                  end

        expect(matched).to eq("matched success: 123")
      end

      it "allows pattern matching on final_answer state" do
        executor.send_tools("final_answer" => Smolagents::Tools::FinalAnswerTool.new)
        outcome = executor.execute_with_outcome("final_answer('done')", language: :ruby) # Positional arg

        matched = case outcome
                  in Smolagents::ExecutorExecutionOutcome[state: :final_answer, value:]
                    "final: #{value}"
                  else
                    "no match"
                  end

        expect(matched).to eq("final: done")
      end

      it "allows pattern matching on error state" do
        outcome = executor.execute_with_outcome("raise 'boom'", language: :ruby)

        matched = case outcome
                  in Smolagents::ExecutorExecutionOutcome[state: :error, error:]
                    "error: #{error.message}"
                  else
                    "no match"
                  end

        expect(matched).to match(/error: RuntimeError: boom/)
      end
    end

    context "composition pattern validation" do
      it "outcome CONTAINS result, doesn't replace it" do
        outcome = executor.execute_with_outcome("99", language: :ruby)

        # Outcome has state machine layer
        expect(outcome).to respond_to(:state)
        expect(outcome).to respond_to(:success?)
        expect(outcome).to respond_to(:error?)
        expect(outcome).to respond_to(:final_answer?)

        # Result is contained and accessible
        expect(outcome.result).to be_a(Smolagents::Executors::Executor::ExecutionResult)
        expect(outcome.result.output).to eq(99)

        # Outcome delegates to result for convenience
        expect(outcome.output).to eq(99)
        expect(outcome.logs).to eq("")
      end

      it "preserves all ExecutionResult data in contained result" do
        executor.send_tools("final_answer" => Smolagents::Tools::FinalAnswerTool.new)
        code = <<~RUBY
          puts "computing..."
          final_answer('answer')  # Positional arg - easier for models
        RUBY

        outcome = executor.execute_with_outcome(code, language: :ruby)

        # All ExecutionResult fields preserved
        expect(outcome.result.output).to eq("answer")
        expect(outcome.result.logs).to include("computing...")
        expect(outcome.result.error).to be_nil
        expect(outcome.result.is_final_answer).to be true
      end
    end

    context "instrumentation integration" do
      it "can be used with Instrumentation.observe" do
        events = []
        Smolagents::Telemetry::Instrumentation.subscriber = lambda do |event, payload|
          events << { event: event, payload: payload }
        end

        outcome = Smolagents::Telemetry::Instrumentation.observe(
          "smolagents.custom.event",
          executor_class: "RubyExecutor"
        ) do
          executor.execute_with_outcome("42", language: :ruby)
        end

        # Instrumentation returns outcome unchanged
        expect(outcome).to be_a(Smolagents::ExecutorExecutionOutcome)
        expect(outcome.success?).to be true
        expect(outcome.value).to eq(42)

        # Events were emitted: one from execute(), one from observe()
        expect(events.size).to eq(2)

        # First event is from execute() instrumentation (legacy)
        execute_event = events.find { |e| e[:event] == "smolagents.executor.execute" }
        expect(execute_event).not_to be_nil
        expect(execute_event[:payload][:executor_class]).to eq("Smolagents::Executors::LocalRuby")

        # Second event is from observe() with outcome data
        outcome_event = events.find { |e| e[:event] == "smolagents.custom.event" }
        expect(outcome_event).not_to be_nil
        expect(outcome_event[:payload][:outcome]).to eq(:success)
        expect(outcome_event[:payload][:duration]).to be > 0
        expect(outcome_event[:payload][:output]).to eq(42)
      ensure
        Smolagents::Telemetry::Instrumentation.subscriber = nil
      end
    end
  end
end
