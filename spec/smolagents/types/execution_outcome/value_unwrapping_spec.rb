require "spec_helper"

RSpec.describe Smolagents::Types::OutcomeComponents::ValueUnwrapping do
  # Test type that includes both Predicates (for error?/failed?) and ValueUnwrapping
  let(:test_outcome) do
    Class.new(Data.define(:state, :value, :error)) do
      include Smolagents::Types::OutcomeComponents::Predicates
      include Smolagents::Types::OutcomeComponents::ValueUnwrapping
    end
  end

  describe "#value!" do
    context "when outcome is successful" do
      it "returns the value for success state" do
        outcome = test_outcome.new(state: :success, value: "result", error: nil)
        expect(outcome.value!).to eq("result")
      end

      it "returns the value for final_answer state" do
        outcome = test_outcome.new(state: :final_answer, value: "answer", error: nil)
        expect(outcome.value!).to eq("answer")
      end

      it "returns nil value when value is explicitly nil" do
        outcome = test_outcome.new(state: :success, value: nil, error: nil)
        expect(outcome.value!).to be_nil
      end

      it "returns complex values" do
        complex_value = { results: [1, 2, 3], meta: { count: 3 } }
        outcome = test_outcome.new(state: :success, value: complex_value, error: nil)
        expect(outcome.value!).to eq(complex_value)
      end
    end

    context "when outcome is error" do
      it "raises the stored error" do
        error = StandardError.new("something went wrong")
        outcome = test_outcome.new(state: :error, value: nil, error:)

        expect { outcome.value! }.to raise_error(StandardError, "something went wrong")
      end

      it "raises the original error class" do
        error = ArgumentError.new("invalid argument")
        outcome = test_outcome.new(state: :error, value: nil, error:)

        expect { outcome.value! }.to raise_error(ArgumentError, "invalid argument")
      end

      it "raises custom error classes" do
        error = CustomTestError.new("custom error")
        outcome = test_outcome.new(state: :error, value: nil, error:)

        expect { outcome.value! }.to raise_error(CustomTestError, "custom error")
      end
    end

    context "when outcome failed without explicit error" do
      it "raises StandardError for max_steps_reached state" do
        outcome = test_outcome.new(state: :max_steps_reached, value: nil, error: nil)

        expect { outcome.value! }.to raise_error(StandardError, /Operation failed: max_steps_reached/)
      end

      it "raises StandardError for timeout state" do
        outcome = test_outcome.new(state: :timeout, value: nil, error: nil)

        expect { outcome.value! }.to raise_error(StandardError, /Operation failed: timeout/)
      end
    end
  end
end

# Custom error class for testing
class CustomTestError < StandardError; end
