require "spec_helper"

RSpec.describe Smolagents::Types::OutcomeComponents::EventSerialization do
  # Test type that includes EventSerialization and Predicates
  let(:test_outcome) do
    Class.new(Data.define(:state, :value, :error, :duration, :metadata)) do
      include Smolagents::Types::OutcomeComponents::Predicates
      include Smolagents::Types::OutcomeComponents::EventSerialization
    end
  end

  describe "#to_event_payload" do
    it "includes outcome state" do
      outcome = test_outcome.new(state: :success, value: "result", error: nil, duration: 1.0, metadata: {})
      expect(outcome.to_event_payload[:outcome]).to eq(:success)
    end

    it "includes duration" do
      outcome = test_outcome.new(state: :success, value: "result", error: nil, duration: 2.5, metadata: {})
      expect(outcome.to_event_payload[:duration]).to eq(2.5)
    end

    it "includes ISO8601 timestamp" do
      Timecop.freeze(Time.utc(2024, 6, 15, 12, 30, 0)) do
        outcome = test_outcome.new(state: :success, value: "result", error: nil, duration: 1.0, metadata: {})
        expect(outcome.to_event_payload[:timestamp]).to eq("2024-06-15T12:30:00Z")
      end
    end

    it "includes metadata" do
      outcome = test_outcome.new(
        state: :success,
        value: "result",
        error: nil,
        duration: 1.0,
        metadata: { tool: "search", step: 1 }
      )
      expect(outcome.to_event_payload[:metadata]).to eq({ tool: "search", step: 1 })
    end

    context "when outcome is completed (success)" do
      it "includes value in payload" do
        outcome = test_outcome.new(state: :success, value: "result", error: nil, duration: 1.0, metadata: {})
        payload = outcome.to_event_payload

        expect(payload[:value]).to eq("result")
        expect(payload).not_to have_key(:error)
        expect(payload).not_to have_key(:error_message)
      end
    end

    context "when outcome is completed (final_answer)" do
      it "includes value in payload" do
        outcome = test_outcome.new(state: :final_answer, value: "answer", error: nil, duration: 1.0, metadata: {})
        payload = outcome.to_event_payload

        expect(payload[:value]).to eq("answer")
      end
    end

    context "when outcome is error" do
      it "includes error class and message" do
        error = ArgumentError.new("invalid input")
        outcome = test_outcome.new(state: :error, value: nil, error:, duration: 0.5, metadata: {})
        payload = outcome.to_event_payload

        expect(payload[:error]).to eq("ArgumentError")
        expect(payload[:error_message]).to eq("invalid input")
        expect(payload).not_to have_key(:value)
      end
    end

    context "when outcome is max_steps or timeout" do
      it "does not include value or error details" do
        outcome = test_outcome.new(state: :max_steps_reached, value: nil, error: nil, duration: 30.0, metadata: {})
        payload = outcome.to_event_payload

        expect(payload).not_to have_key(:value)
        expect(payload).not_to have_key(:error)
        expect(payload).not_to have_key(:error_message)
      end
    end

    it "compacts nil values from payload" do
      outcome = test_outcome.new(state: :timeout, value: nil, error: nil, duration: 60.0, metadata: {})
      payload = outcome.to_event_payload

      # Compact removes nil :value since it's not explicitly added for timeout
      expect(payload.keys).to contain_exactly(:outcome, :duration, :timestamp, :metadata)
    end
  end
end
