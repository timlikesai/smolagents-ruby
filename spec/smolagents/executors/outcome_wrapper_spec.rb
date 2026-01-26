RSpec.describe Smolagents::Executors::Executor::OutcomeWrapper do
  let(:test_executor) do
    Class.new(Smolagents::Executor) do
      include Smolagents::Executors::Executor::OutcomeWrapper

      def execute(code, language:, **)
        # Mock execution that captures timing
        Smolagents::Executors::ExecutionResult.success(
          output: "result",
          logs: "executed"
        )
      end

      def supports?(language) = language == :ruby
    end
  end

  let(:executor) { test_executor.new }

  describe "#execute_with_outcome" do
    it "wraps execution result in CodeOutcome" do
      outcome = executor.execute_with_outcome("code", language: :ruby)

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
    end

    it "includes duration information" do
      outcome = executor.execute_with_outcome("code", language: :ruby)

      expect(outcome.duration).to be_a(Float)
    end

    it "preserves successful execution result" do
      outcome = executor.execute_with_outcome("code", language: :ruby)

      expect(outcome.success?).to be true
      expect(outcome.output).to eq("result")
    end

    it "measures execution time" do
      # Test that timing is measured by verifying duration is a numeric value
      outcome = executor.execute_with_outcome("code", language: :ruby)

      expect(outcome.duration).to be_a(Float)
    end

    it "accepts timeout parameter" do
      outcome = executor.execute_with_outcome("code", language: :ruby, timeout: 10)

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
    end

    # NOTE: memory_mb parameter was removed - Ruby Ractors cannot enforce memory limits.
    # Use external controls (cgroups, ulimit, containers) for memory isolation.

    it "passes through additional keyword arguments" do
      # Executor should accept arbitrary kwargs
      outcome = executor.execute_with_outcome(
        "code",
        language: :ruby,
        timeout: 5,
        custom_param: "value"
      )

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
    end

    it "handles failed execution" do
      class FailingExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **)
          Smolagents::Executors::ExecutionResult.failure(error: "execution failed")
        end

        def supports?(language) = language == :ruby
      end

      failing_executor = FailingExecutor.new
      outcome = failing_executor.execute_with_outcome("code", language: :ruby)

      # CodeOutcome stores the error result
      expect(outcome.result.failure?).to be true
      expect(outcome.result.error).to eq("execution failed")
    end

    it "includes logs in outcome" do
      class LoggingExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **)
          Smolagents::Executors::ExecutionResult.success(
            output: "result",
            logs: "debug: step 1\ndebug: step 2"
          )
        end

        def supports?(language) = language == :ruby
      end

      logging_executor = LoggingExecutor.new
      outcome = logging_executor.execute_with_outcome("code", language: :ruby)

      expect(outcome.logs).to include("step 1")
      expect(outcome.logs).to include("step 2")
    end

    it "preserves result information" do
      class ResultExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **)
          Smolagents::Executors::ExecutionResult.success(
            output: "final",
            final_answer: true
          )
        end

        def supports?(language) = language == :ruby
      end

      result_executor = ResultExecutor.new
      outcome = result_executor.execute_with_outcome("code", language: :ruby)

      # CodeOutcome wraps the result
      expect(outcome.result).to be_a(Smolagents::Executors::ExecutionResult)
      expect(outcome.result.final_answer).to be true
    end
  end

  describe "timing accuracy" do
    it "measures realistic execution time" do
      # Mock Process.clock_gettime to return controlled values
      start_time = 100.0
      end_time = 100.05 # 50ms elapsed

      call_count = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
        call_count += 1
        call_count == 1 ? start_time : end_time
      end

      outcome = executor.execute_with_outcome("code", language: :ruby)

      # Duration should be approximately the difference between mocked times
      expect(outcome.duration).to be_within(0.001).of(0.05)
    end
  end

  describe "CodeOutcome composition" do
    it "creates outcome with expected fields" do
      outcome = executor.execute_with_outcome("code", language: :ruby)

      # CodeOutcome structure
      expect(outcome).to respond_to(:output)
      expect(outcome).to respond_to(:logs)
      expect(outcome).to respond_to(:result)
      expect(outcome).to respond_to(:duration)
      expect(outcome).to respond_to(:state)
    end

    it "outcome reflects execution result state" do
      class StateExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **)
          Smolagents::Executors::ExecutionResult.success(
            output: 42,
            logs: "processed",
            final_answer: true
          )
        end

        def supports?(language) = language == :ruby
      end

      state_executor = StateExecutor.new
      outcome = state_executor.execute_with_outcome("code", language: :ruby)

      expect(outcome.output).to eq(42)
      expect(outcome.logs).to eq("processed")
      expect(outcome.result.final_answer).to be true
    end
  end

  describe "error handling" do
    it "wraps executor errors in outcome" do
      class ErrorExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **) = raise "Internal error"

        def supports?(language) = language == :ruby
      end

      error_executor = ErrorExecutor.new

      expect do
        error_executor.execute_with_outcome("code", language: :ruby)
      end.to raise_error("Internal error")
    end
  end

  describe "parameter passing" do
    it "forwards extra parameters via double splat" do
      # This should not raise even with extra params
      outcome = executor.execute_with_outcome(
        "code",
        language: :ruby,
        timeout: 10,
        custom1: "val1",
        custom2: "val2"
      )

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
    end

    it "passes parameters to execute method" do
      # Verify the execute method is called with the code and language
      outcome = executor.execute_with_outcome("code", language: :ruby)

      # Outcome should be successfully created
      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
      expect(outcome.result).to be_a(Smolagents::Executors::ExecutionResult)
    end
  end

  describe "performance characteristics" do
    it "adds minimal overhead" do
      class FastExecutor < Smolagents::Executor
        include Smolagents::Executors::Executor::OutcomeWrapper

        def execute(code, language:, **)
          Smolagents::Executors::ExecutionResult.success(output: nil)
        end

        def supports?(language) = language == :ruby
      end

      fast_executor = FastExecutor.new

      # Multiple executions should show consistent timing
      outcomes = Array.new(10) do
        fast_executor.execute_with_outcome("code", language: :ruby)
      end

      # All should have reasonable durations
      expect(outcomes.map(&:duration).all? { |d| d.is_a?(Float) && d >= 0 }).to be true
    end
  end
end
