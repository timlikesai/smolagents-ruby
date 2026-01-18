require "smolagents"

RSpec.describe Smolagents::Outcome do
  describe "constants" do
    it "defines all outcome states" do
      expect(described_class::SUCCESS).to eq(:success)
      expect(described_class::PARTIAL).to eq(:partial)
      expect(described_class::FAILURE).to eq(:failure)
      expect(described_class::ERROR).to eq(:error)
      expect(described_class::MAX_STEPS).to eq(:max_steps_reached)
      expect(described_class::TIMEOUT).to eq(:timeout)
      expect(described_class::FINAL_ANSWER).to eq(:final_answer)
    end

    it "defines ALL as frozen array of all states" do
      expect(described_class::ALL).to contain_exactly(
        :success, :partial, :failure, :error, :max_steps_reached, :timeout, :final_answer
      )
      expect(described_class::ALL).to be_frozen
    end

    it "defines TERMINAL states" do
      expect(described_class::TERMINAL).to contain_exactly(:success, :failure, :error, :timeout, :final_answer)
    end

    it "defines RETRIABLE states" do
      expect(described_class::RETRIABLE).to contain_exactly(:partial, :max_steps_reached)
    end

    it "defines COMPLETED states" do
      expect(described_class::COMPLETED).to contain_exactly(:success, :final_answer)
    end

    it "defines FAILED states" do
      expect(described_class::FAILED).to contain_exactly(:failure, :error, :max_steps_reached, :timeout)
    end
  end

  describe "individual state predicates" do
    it ".success? returns true only for :success" do
      expect(described_class.success?(:success)).to be true
      expect(described_class.success?(:failure)).to be false
    end

    it ".partial? returns true only for :partial" do
      expect(described_class.partial?(:partial)).to be true
      expect(described_class.partial?(:success)).to be false
    end

    it ".failure? returns true only for :failure" do
      expect(described_class.failure?(:failure)).to be true
      expect(described_class.failure?(:success)).to be false
    end

    it ".error? returns true only for :error" do
      expect(described_class.error?(:error)).to be true
      expect(described_class.error?(:success)).to be false
    end

    it ".max_steps? returns true only for :max_steps_reached" do
      expect(described_class.max_steps?(:max_steps_reached)).to be true
      expect(described_class.max_steps?(:success)).to be false
    end

    it ".timeout? returns true only for :timeout" do
      expect(described_class.timeout?(:timeout)).to be true
      expect(described_class.timeout?(:success)).to be false
    end

    it ".final_answer? returns true only for :final_answer" do
      expect(described_class.final_answer?(:final_answer)).to be true
      expect(described_class.final_answer?(:success)).to be false
    end
  end

  describe "group predicates" do
    it ".terminal? returns true for terminal states" do
      %i[success failure error timeout final_answer].each do |state|
        expect(described_class.terminal?(state)).to be true
      end
      expect(described_class.terminal?(:partial)).to be false
      expect(described_class.terminal?(:max_steps_reached)).to be false
    end

    it ".retriable? returns true for retriable states" do
      expect(described_class.retriable?(:partial)).to be true
      expect(described_class.retriable?(:max_steps_reached)).to be true
      expect(described_class.retriable?(:success)).to be false
    end

    it ".completed? returns true for completed states" do
      expect(described_class.completed?(:success)).to be true
      expect(described_class.completed?(:final_answer)).to be true
      expect(described_class.completed?(:failure)).to be false
    end

    it ".failed? returns true for failed states" do
      %i[failure error max_steps_reached timeout].each do |state|
        expect(described_class.failed?(state)).to be true
      end
      expect(described_class.failed?(:success)).to be false
      expect(described_class.failed?(:final_answer)).to be false
    end

    it ".valid? returns true for all valid states" do
      described_class::ALL.each do |state|
        expect(described_class.valid?(state)).to be true
      end
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe ".from_run_result" do
    let(:success_result) { instance_double(Smolagents::RunResult, state: :success) }
    let(:final_answer_result) { instance_double(Smolagents::RunResult, state: :final_answer) }
    let(:max_steps_result) { instance_double(Smolagents::RunResult, state: :max_steps_reached) }
    let(:failure_result) { instance_double(Smolagents::RunResult, state: :failure) }
    let(:unknown_result) { instance_double(Smolagents::RunResult, state: :unknown) }

    it "returns ERROR when error is present" do
      expect(described_class.from_run_result(success_result, error: StandardError.new)).to eq(:error)
    end

    it "passes through valid states" do
      expect(described_class.from_run_result(success_result)).to eq(:success)
      expect(described_class.from_run_result(final_answer_result)).to eq(:final_answer)
      expect(described_class.from_run_result(max_steps_result)).to eq(:max_steps_reached)
      expect(described_class.from_run_result(failure_result)).to eq(:failure)
    end

    it "returns FAILURE for unknown states" do
      expect(described_class.from_run_result(unknown_result)).to eq(:failure)
    end
  end

  describe ".===" do
    it "supports pattern matching on valid outcomes via case/when" do
      # Use variables to avoid LiteralAsCondition cop
      valid_state = :success
      invalid_state = :invalid

      matched = case valid_state
                when described_class then true
                else false
                end
      expect(matched).to be true

      matched = case invalid_state
                when described_class then true
                else false
                end
      expect(matched).to be false
    end
  end
end
