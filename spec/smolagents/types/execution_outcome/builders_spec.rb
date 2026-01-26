require "spec_helper"

RSpec.describe Smolagents::Types::OutcomeComponents::Builders do
  # Test type that extends Builders
  let(:test_outcome) do
    Class.new(Data.define(:state, :value, :error, :duration, :metadata)) do
      extend Smolagents::Types::OutcomeComponents::Builders
    end
  end

  describe ".success" do
    it "creates outcome with success state" do
      outcome = test_outcome.success("result")

      expect(outcome.state).to eq(:success)
      expect(outcome.value).to eq("result")
      expect(outcome.error).to be_nil
    end

    it "sets default duration to 0.0" do
      outcome = test_outcome.success("result")
      expect(outcome.duration).to eq(0.0)
    end

    it "sets default metadata to empty hash" do
      outcome = test_outcome.success("result")
      expect(outcome.metadata).to eq({})
    end

    it "accepts custom duration" do
      outcome = test_outcome.success("result", duration: 1.5)
      expect(outcome.duration).to eq(1.5)
    end

    it "accepts custom metadata" do
      outcome = test_outcome.success("result", metadata: { tool: "search" })
      expect(outcome.metadata).to eq({ tool: "search" })
    end
  end

  describe ".final_answer" do
    it "creates outcome with final_answer state" do
      outcome = test_outcome.final_answer("the answer")

      expect(outcome.state).to eq(:final_answer)
      expect(outcome.value).to eq("the answer")
      expect(outcome.error).to be_nil
    end

    it "accepts duration and metadata" do
      outcome = test_outcome.final_answer("answer", duration: 2.0, metadata: { step: 5 })

      expect(outcome.duration).to eq(2.0)
      expect(outcome.metadata).to eq({ step: 5 })
    end
  end

  describe ".error" do
    let(:error) { StandardError.new("something went wrong") }

    it "creates outcome with error state" do
      outcome = test_outcome.error(error)

      expect(outcome.state).to eq(:error)
      expect(outcome.error).to eq(error)
      expect(outcome.value).to be_nil
    end

    it "accepts duration and metadata" do
      outcome = test_outcome.error(error, duration: 0.5, metadata: { retries: 3 })

      expect(outcome.duration).to eq(0.5)
      expect(outcome.metadata).to eq({ retries: 3 })
    end
  end

  describe ".max_steps" do
    it "creates outcome with max_steps_reached state" do
      outcome = test_outcome.max_steps(steps_taken: 10)

      expect(outcome.state).to eq(:max_steps_reached)
      expect(outcome.value).to be_nil
      expect(outcome.error).to be_nil
    end

    it "stores steps_taken in metadata" do
      outcome = test_outcome.max_steps(steps_taken: 10)
      expect(outcome.metadata[:steps_taken]).to eq(10)
    end

    it "merges steps_taken with provided metadata" do
      outcome = test_outcome.max_steps(steps_taken: 10, metadata: { task: "research" })

      expect(outcome.metadata[:steps_taken]).to eq(10)
      expect(outcome.metadata[:task]).to eq("research")
    end

    it "accepts custom duration" do
      outcome = test_outcome.max_steps(steps_taken: 10, duration: 30.0)
      expect(outcome.duration).to eq(30.0)
    end
  end

  describe ".timeout" do
    it "creates outcome with timeout state" do
      outcome = test_outcome.timeout

      expect(outcome.state).to eq(:timeout)
      expect(outcome.value).to be_nil
      expect(outcome.error).to be_nil
    end

    it "accepts duration and metadata" do
      outcome = test_outcome.timeout(duration: 60.0, metadata: { limit: 60 })

      expect(outcome.duration).to eq(60.0)
      expect(outcome.metadata).to eq({ limit: 60 })
    end
  end
end
