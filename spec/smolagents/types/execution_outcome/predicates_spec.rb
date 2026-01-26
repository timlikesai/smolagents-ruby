require "spec_helper"

RSpec.describe Smolagents::Types::OutcomeComponents::Predicates do
  # Test type that includes Predicates
  let(:test_outcome) do
    Class.new(Data.define(:state, :value)) do
      include Smolagents::Types::OutcomeComponents::Predicates
    end
  end

  describe "state predicates via StatePredicates" do
    it "defines success? predicate" do
      outcome = test_outcome.new(state: :success, value: "ok")
      expect(outcome.success?).to be true
      expect(outcome.error?).to be false
    end

    it "defines final_answer? predicate" do
      outcome = test_outcome.new(state: :final_answer, value: "answer")
      expect(outcome.final_answer?).to be true
      expect(outcome.success?).to be false
    end

    it "defines error? predicate" do
      outcome = test_outcome.new(state: :error, value: nil)
      expect(outcome.error?).to be true
    end

    it "defines max_steps? predicate for :max_steps_reached state" do
      outcome = test_outcome.new(state: :max_steps_reached, value: nil)
      expect(outcome.max_steps?).to be true
    end

    it "defines timeout? predicate" do
      outcome = test_outcome.new(state: :timeout, value: nil)
      expect(outcome.timeout?).to be true
    end
  end

  describe "#completed?" do
    it "returns true for success state" do
      outcome = test_outcome.new(state: :success, value: "result")
      expect(outcome.completed?).to be true
    end

    it "returns true for final_answer state" do
      outcome = test_outcome.new(state: :final_answer, value: "answer")
      expect(outcome.completed?).to be true
    end

    it "returns false for error state" do
      outcome = test_outcome.new(state: :error, value: nil)
      expect(outcome.completed?).to be false
    end

    it "returns false for max_steps_reached state" do
      outcome = test_outcome.new(state: :max_steps_reached, value: nil)
      expect(outcome.completed?).to be false
    end

    it "returns false for timeout state" do
      outcome = test_outcome.new(state: :timeout, value: nil)
      expect(outcome.completed?).to be false
    end
  end

  describe "#failed?" do
    it "returns true for error state" do
      outcome = test_outcome.new(state: :error, value: nil)
      expect(outcome.failed?).to be true
    end

    it "returns true for max_steps_reached state" do
      outcome = test_outcome.new(state: :max_steps_reached, value: nil)
      expect(outcome.failed?).to be true
    end

    it "returns true for timeout state" do
      outcome = test_outcome.new(state: :timeout, value: nil)
      expect(outcome.failed?).to be true
    end

    it "returns false for success state" do
      outcome = test_outcome.new(state: :success, value: "result")
      expect(outcome.failed?).to be false
    end

    it "returns false for final_answer state" do
      outcome = test_outcome.new(state: :final_answer, value: "answer")
      expect(outcome.failed?).to be false
    end
  end

  describe "completed? and failed? are mutually exclusive" do
    it "never has both true" do
      states = %i[success final_answer error max_steps_reached timeout]

      states.each do |state|
        outcome = test_outcome.new(state:, value: nil)
        message = "Expected exactly one of completed?/failed? to be true for #{state}, " \
                  "got completed?=#{outcome.completed?}, failed?=#{outcome.failed?}"
        expect([outcome.completed?, outcome.failed?].count(true)).to eq(1), message
      end
    end
  end
end
