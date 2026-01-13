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
    end

    it "defines ALL as frozen array of all states" do
      expect(described_class::ALL).to contain_exactly(:success, :partial, :failure, :error, :max_steps_reached, :timeout)
      expect(described_class::ALL).to be_frozen
    end

    it "defines TERMINAL states" do
      expect(described_class::TERMINAL).to contain_exactly(:success, :failure, :error, :timeout)
    end

    it "defines RETRIABLE states" do
      expect(described_class::RETRIABLE).to contain_exactly(:partial, :max_steps_reached)
    end
  end

  describe ".success?" do
    it "returns true for SUCCESS" do
      expect(described_class.success?(:success)).to be true
    end

    it "returns false for other states" do
      expect(described_class.success?(:failure)).to be false
      expect(described_class.success?(:error)).to be false
    end
  end

  describe ".partial?" do
    it "returns true for PARTIAL" do
      expect(described_class.partial?(:partial)).to be true
    end

    it "returns false for other states" do
      expect(described_class.partial?(:success)).to be false
    end
  end

  describe ".terminal?" do
    it "returns true for terminal states" do
      expect(described_class.terminal?(:success)).to be true
      expect(described_class.terminal?(:failure)).to be true
      expect(described_class.terminal?(:error)).to be true
      expect(described_class.terminal?(:timeout)).to be true
    end

    it "returns false for non-terminal states" do
      expect(described_class.terminal?(:partial)).to be false
      expect(described_class.terminal?(:max_steps_reached)).to be false
    end
  end

  describe ".retriable?" do
    it "returns true for retriable states" do
      expect(described_class.retriable?(:partial)).to be true
      expect(described_class.retriable?(:max_steps_reached)).to be true
    end

    it "returns false for non-retriable states" do
      expect(described_class.retriable?(:success)).to be false
      expect(described_class.retriable?(:failure)).to be false
    end
  end

  describe ".valid?" do
    it "returns true for valid states" do
      described_class::ALL.each do |state|
        expect(described_class.valid?(state)).to be true
      end
    end

    it "returns false for invalid states" do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe ".from_run_result" do
    let(:success_result) { instance_double(Smolagents::RunResult, state: :success, success?: true) }
    let(:max_steps_result) { instance_double(Smolagents::RunResult, state: :max_steps_reached, success?: false) }
    let(:failure_result) { instance_double(Smolagents::RunResult, state: :failure, success?: false) }

    it "returns ERROR when error is present" do
      expect(described_class.from_run_result(success_result, error: StandardError.new)).to eq(:error)
    end

    it "returns MAX_STEPS for max_steps_reached state" do
      expect(described_class.from_run_result(max_steps_result)).to eq(:max_steps_reached)
    end

    it "returns SUCCESS for successful result" do
      expect(described_class.from_run_result(success_result)).to eq(:success)
    end

    it "returns FAILURE for other cases" do
      expect(described_class.from_run_result(failure_result)).to eq(:failure)
    end
  end
end
