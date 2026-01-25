require "spec_helper"

RSpec.describe Smolagents::Concerns::ReliabilityEvents do
  describe "RetryEvent" do
    let(:model) do
      double("Model", model_id: "gpt-4")
    end

    let(:error) do
      StandardError.new("Connection timeout")
    end

    let(:event) do
      described_class::RetryEvent.new(
        model:,
        error:,
        attempt: 2,
        max_attempts: 5,
        suggested_interval: 2.5
      )
    end

    describe "attributes" do
      it "stores model" do
        expect(event.model).to eq(model)
      end

      it "stores error" do
        expect(event.error).to eq(error)
      end

      it "stores attempt number" do
        expect(event.attempt).to eq(2)
      end

      it "stores max attempts" do
        expect(event.max_attempts).to eq(5)
      end

      it "stores suggested interval" do
        expect(event.suggested_interval).to eq(2.5)
      end
    end

    describe "#to_h" do
      it "converts to hash" do
        hash = event.to_h
        expect(hash).to be_a(Hash)
      end

      it "extracts model_id from model" do
        hash = event.to_h
        expect(hash[:model]).to eq("gpt-4")
      end

      it "includes error message" do
        hash = event.to_h
        expect(hash[:error]).to eq("Connection timeout")
      end

      it "includes attempt number" do
        hash = event.to_h
        expect(hash[:attempt]).to eq(2)
      end

      it "includes max attempts" do
        hash = event.to_h
        expect(hash[:max_attempts]).to eq(5)
      end

      it "includes suggested interval" do
        hash = event.to_h
        expect(hash[:suggested_interval]).to eq(2.5)
      end

      it "handles different error types" do
        timeout_error = Timeout::Error.new("Request timed out")
        event = described_class::RetryEvent.new(
          model:,
          error: timeout_error,
          attempt: 1,
          max_attempts: 3,
          suggested_interval: 1.0
        )
        hash = event.to_h
        expect(hash[:error]).to eq("Request timed out")
      end
    end

    describe "immutability" do
      it "is immutable" do
        expect { event.model = "new_model" }.to raise_error(NoMethodError)
      end

      it "is frozen" do
        expect(event).to be_frozen
      end
    end
  end

  describe "FailoverEvent" do
    let(:from_model) do
      double("Model", model_id: "primary-gpt4")
    end

    let(:to_model) do
      double("Model", model_id: "backup-gpt35")
    end

    let(:error) do
      StandardError.new("API rate limit exceeded")
    end

    let(:event) do
      described_class::FailoverEvent.new(
        from_model:,
        to_model:,
        error:,
        attempt: 3,
        timestamp: Time.now
      )
    end

    describe "attributes" do
      it "stores from_model" do
        expect(event.from_model).to eq(from_model)
      end

      it "stores to_model" do
        expect(event.to_model).to eq(to_model)
      end

      it "stores error" do
        expect(event.error).to eq(error)
      end

      it "stores attempt number" do
        expect(event.attempt).to eq(3)
      end

      it "stores timestamp" do
        expect(event.timestamp).to be_a(Time)
      end

      it "allows nil to_model" do
        event = described_class::FailoverEvent.new(
          from_model:,
          to_model: nil,
          error:,
          attempt: 1,
          timestamp: Time.now
        )
        expect(event.to_model).to be_nil
      end
    end

    describe "#to_h" do
      it "converts to hash" do
        hash = event.to_h
        expect(hash).to be_a(Hash)
      end

      it "includes from_model" do
        hash = event.to_h
        expect(hash[:from]).to eq(from_model)
      end

      it "includes to_model" do
        hash = event.to_h
        expect(hash[:to]).to eq(to_model)
      end

      it "includes error message" do
        hash = event.to_h
        expect(hash[:error]).to eq("API rate limit exceeded")
      end

      it "includes attempt" do
        hash = event.to_h
        expect(hash[:attempt]).to eq(3)
      end

      it "converts timestamp to ISO8601" do
        now = Time.parse("2024-01-15 10:30:00 UTC")
        event = described_class::FailoverEvent.new(
          from_model:,
          to_model:,
          error:,
          attempt: 1,
          timestamp: now
        )
        hash = event.to_h
        expect(hash[:timestamp]).to match(/2024-01-15T10:30:00/)
      end

      it "handles nil to_model in hash" do
        event = described_class::FailoverEvent.new(
          from_model:,
          to_model: nil,
          error:,
          attempt: 1,
          timestamp: Time.now
        )
        hash = event.to_h
        expect(hash[:to]).to be_nil
      end

      it "preserves model object references in hash" do
        hash = event.to_h
        expect(hash[:from]).to be(from_model)
        expect(hash[:to]).to be(to_model)
      end
    end

    describe "immutability" do
      it "is immutable" do
        expect { event.from_model = "new_model" }.to raise_error(NoMethodError)
      end

      it "is frozen" do
        expect(event).to be_frozen
      end
    end
  end

  describe "Event usage patterns" do
    let(:model) { double("Model", model_id: "test-model") }

    it "allows RetryEvent to be created for monitoring" do
      events = []
      error = StandardError.new("Failure")

      (1..3).each do |attempt|
        event = Smolagents::Concerns::ReliabilityEvents::RetryEvent.new(
          model:,
          error:,
          attempt:,
          max_attempts: 3,
          suggested_interval: 1.0 * attempt
        )
        events << event
      end

      expect(events.size).to eq(3)
      expect(events.first.attempt).to eq(1)
      expect(events.last.attempt).to eq(3)
    end

    it "tracks failover chain" do
      models = [
        double("Model", model_id: "primary"),
        double("Model", model_id: "secondary"),
        double("Model", model_id: "tertiary")
      ]

      error = StandardError.new("Primary failed")

      failovers = []
      (0...(models.size - 1)).each do |i|
        event = Smolagents::Concerns::ReliabilityEvents::FailoverEvent.new(
          from_model: models[i],
          to_model: models[i + 1],
          error:,
          attempt: i + 1,
          timestamp: Time.now
        )
        failovers << event
      end

      expect(failovers.size).to eq(2)
      expect(failovers.first.from_model.model_id).to eq("primary")
      expect(failovers.first.to_model.model_id).to eq("secondary")
      expect(failovers.last.from_model.model_id).to eq("secondary")
      expect(failovers.last.to_model.model_id).to eq("tertiary")
    end

    it "serializes events for logging" do
      retry_event = Smolagents::Concerns::ReliabilityEvents::RetryEvent.new(
        model:,
        error: StandardError.new("Timeout"),
        attempt: 1,
        max_attempts: 3,
        suggested_interval: 1.0
      )

      failover_event = Smolagents::Concerns::ReliabilityEvents::FailoverEvent.new(
        from_model: model,
        to_model: double("BackupModel", model_id: "backup"),
        error: StandardError.new("Failed"),
        attempt: 1,
        timestamp: Time.now
      )

      retry_hash = retry_event.to_h
      failover_hash = failover_event.to_h

      expect(retry_hash[:error]).to eq("Timeout")
      expect(failover_hash[:error]).to eq("Failed")
    end
  end

  describe "Event types" do
    it "RetryEvent is a Data class" do
      model = double("Model", model_id: "test")
      event = described_class::RetryEvent.new(
        model:,
        error: StandardError.new("Error"),
        attempt: 1,
        max_attempts: 3,
        suggested_interval: 1.0
      )
      expect(event).to be_a(described_class::RetryEvent)
    end

    it "FailoverEvent is a Data class" do
      m1 = double("Model", model_id: "m1")
      m2 = double("Model", model_id: "m2")
      event = described_class::FailoverEvent.new(
        from_model: m1,
        to_model: m2,
        error: StandardError.new("Error"),
        attempt: 1,
        timestamp: Time.now
      )
      expect(event).to be_a(described_class::FailoverEvent)
    end
  end
end
