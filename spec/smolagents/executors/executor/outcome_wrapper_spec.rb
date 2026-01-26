require "spec_helper"

RSpec.describe Smolagents::Executors::Executor::OutcomeWrapper do
  # Create a test executor that includes OutcomeWrapper
  let(:executor_class) do
    Class.new(Smolagents::Executors::Executor) do
      include Smolagents::Executors::Executor::OutcomeWrapper

      def supports?(language)
        language == :ruby
      end

      def execute(code, language:, timeout: 5, memory_mb: 256, **)
        # Simulate execution by evaluating simple expressions
        output = eval(code) # rubocop:disable Security/Eval -- test only
        Smolagents::Executors::ExecutionResult.success(output:)
      rescue StandardError => e
        Smolagents::Executors::ExecutionResult.failure(error: e.message)
      end
    end
  end

  let(:executor) { executor_class.new }

  describe "#execute_with_outcome" do
    it "wraps successful result in CodeOutcome" do
      outcome = executor.execute_with_outcome("1 + 2", language: :ruby)

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
      expect(outcome.state).to eq(:success)
      expect(outcome.value).to eq(3)
      expect(outcome.error).to be_nil
    end

    it "wraps failed result in CodeOutcome" do
      outcome = executor.execute_with_outcome("undefined_var", language: :ruby)

      expect(outcome).to be_a(Smolagents::Types::CodeOutcome)
      expect(outcome.state).to eq(:error)
      expect(outcome.error).to be_a(StandardError)
    end

    it "includes duration timing" do
      outcome = executor.execute_with_outcome("42", language: :ruby)

      expect(outcome.duration).to be_a(Float)
    end

    it "passes through execution parameters" do
      # Verify timeout and memory_mb are passed (though not enforced in test executor)
      outcome = executor.execute_with_outcome("100", language: :ruby, timeout: 10, memory_mb: 512)

      expect(outcome.state).to eq(:success)
      expect(outcome.value).to eq(100)
    end

    it "preserves execution result in outcome" do
      outcome = executor.execute_with_outcome("[1, 2, 3].sum", language: :ruby)

      expect(outcome.result).to be_a(Smolagents::Executors::ExecutionResult)
      expect(outcome.result.output).to eq(6)
      expect(outcome.result.success?).to be true
    end

    it "handles final_answer result" do
      final_executor_class = Class.new(Smolagents::Executors::Executor) do
        include Smolagents::Executors::Executor::OutcomeWrapper

        def supports?(_) = true

        def execute(_code, **)
          Smolagents::Executors::ExecutionResult.success(output: "final", final_answer: true)
        end
      end

      executor = final_executor_class.new
      outcome = executor.execute_with_outcome("ignored", language: :ruby)

      expect(outcome.state).to eq(:final_answer)
      expect(outcome.value).to eq("final")
    end
  end
end
