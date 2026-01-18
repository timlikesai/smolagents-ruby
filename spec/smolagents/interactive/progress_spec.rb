require "spec_helper"

RSpec.describe Smolagents::Interactive::Progress do
  let(:output) { StringIO.new }

  after do
    described_class.disable
  end

  describe ".enable" do
    it "creates progress components" do
      described_class.enable(output:)

      expect(described_class.spinner).to be_a(Smolagents::Interactive::Progress::Spinner)
      expect(described_class.step_tracker).to be_a(Smolagents::Interactive::Progress::StepTracker)
      expect(described_class.token_counter).to be_a(Smolagents::Interactive::Progress::TokenCounter)
    end

    it "enables the progress display" do
      described_class.enable(output:)
      expect(described_class).to be_enabled
    end

    it "returns self for chaining" do
      expect(described_class.enable(output:)).to eq described_class
    end
  end

  describe ".disable" do
    it "clears all components" do
      described_class.enable(output:)
      described_class.disable

      expect(described_class.spinner).to be_nil
      expect(described_class.step_tracker).to be_nil
      expect(described_class.token_counter).to be_nil
    end

    it "disables the progress display" do
      described_class.enable(output:)
      described_class.disable
      expect(described_class).not_to be_enabled
    end
  end

  describe ".enabled?" do
    it "returns false when not enabled" do
      expect(described_class).not_to be_enabled
    end

    it "returns true when enabled" do
      described_class.enable(output:)
      expect(described_class).to be_enabled
    end
  end

  describe "event handling" do
    before do
      described_class.enable(output:)
    end

    describe "agent.run events" do
      it "resets trackers on start" do
        # Add some data first
        described_class.token_counter.add(input: 100)
        described_class.step_tracker.complete_step(1, :success)

        # Simulate agent run start
        Smolagents::Telemetry::Instrumentation.subscriber.call(
          "smolagents.agent.run",
          { outcome: nil }
        )

        expect(described_class.token_counter.total_tokens).to eq 0
        expect(described_class.step_tracker.completed_steps).to be_empty
      end
    end

    describe "agent.step events" do
      it "starts a step on step start" do
        Smolagents::Telemetry::Instrumentation.subscriber.call(
          "smolagents.agent.step",
          { step_number: 1, outcome: nil }
        )

        expect(described_class.step_tracker.current_step).to eq 1
      end

      it "completes a step on success" do
        Smolagents::Telemetry::Instrumentation.subscriber.call(
          "smolagents.agent.step",
          { step_number: 1, outcome: :success }
        )

        expect(described_class.step_tracker.completed_steps).to contain_exactly(
          hash_including(step: 1, outcome: :success)
        )
      end
    end

    describe "model.generate events" do
      it "tracks tokens on success" do
        Smolagents::Telemetry::Instrumentation.subscriber.call(
          "smolagents.model.generate",
          { outcome: :success, input_tokens: 100, output_tokens: 50 }
        )

        expect(described_class.token_counter.input_tokens).to eq 100
        expect(described_class.token_counter.output_tokens).to eq 50
      end

      it "tracks tokens from usage hash" do
        Smolagents::Telemetry::Instrumentation.subscriber.call(
          "smolagents.model.generate",
          { outcome: :success, usage: { input_tokens: 200, output_tokens: 100 } }
        )

        expect(described_class.token_counter.input_tokens).to eq 200
        expect(described_class.token_counter.output_tokens).to eq 100
      end
    end
  end

  describe "subscriber chaining" do
    it "chains to previous subscriber" do
      previous_events = []
      previous_subscriber = ->(event, payload) { previous_events << [event, payload] }
      Smolagents::Telemetry::Instrumentation.subscriber = previous_subscriber

      described_class.enable(output:)

      Smolagents::Telemetry::Instrumentation.subscriber.call(
        "smolagents.agent.step",
        { step_number: 1, outcome: :success }
      )

      expect(previous_events).to contain_exactly(
        ["smolagents.agent.step", hash_including(step_number: 1, outcome: :success)]
      )
    end

    it "restores previous subscriber on disable" do
      previous_subscriber = ->(_event, _payload) {}
      Smolagents::Telemetry::Instrumentation.subscriber = previous_subscriber

      described_class.enable(output:)
      described_class.disable

      expect(Smolagents::Telemetry::Instrumentation.subscriber).to eq previous_subscriber
    end
  end
end
