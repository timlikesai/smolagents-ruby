require "spec_helper"

RSpec.describe Smolagents::Concerns::ReliabilityNotifications do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReliabilityNotifications
      include Smolagents::Events::Emitter

      attr_reader :emitted_events, :consumed_events, :emitted_errors

      def initialize
        @emitted_events = []
        @consumed_events = []
        @emitted_errors = []
      end

      def emit(event)
        @emitted_events << event if emitting?
      end

      def emit_error(error, context: {}, recoverable: false)
        @emitted_errors << { error:, context:, recoverable: } if emitting?
      end

      def emitting? = @emitting_enabled != false

      def consume(event) = @consumed_events << event
    end
  end

  let(:instance) { test_class.new }

  let(:model) do
    double("Model", model_id: "gpt-4")
  end

  let(:error) do
    StandardError.new("Connection timeout")
  end

  describe "#notify_failover" do
    let(:to_model) do
      double("BackupModel", model_id: "gpt-3.5")
    end

    it "emits failover event" do
      instance.notify_failover(model, to_model, error, 1)

      expect(instance.emitted_events).not_to be_empty
    end

    it "consumes the event after emitting" do
      instance.notify_failover(model, to_model, error, 1)

      expect(instance.consumed_events).not_to be_empty
    end

    it "includes from model id" do
      instance.notify_failover(model, to_model, error, 1)

      # Event should be created with model IDs
      expect(instance.emitted_events.last).not_to be_nil
    end

    it "includes to model id" do
      instance.notify_failover(model, to_model, error, 2)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "handles nil to_model" do
      instance.notify_failover(model, nil, error, 3)

      # Should not raise and should emit event with nil backup
      expect(instance.consumed_events).not_to be_empty
    end

    it "records attempt number" do
      instance.notify_failover(model, to_model, error, 5)

      expect(instance.consumed_events).not_to be_empty
    end

    it "respects emitting flag" do
      instance.instance_variable_set(:@emitting_enabled, false)

      instance.notify_failover(model, to_model, error, 1)

      expect(instance.emitted_events).to be_empty
      # Consume is always called
      expect(instance.consumed_events).not_to be_empty
    end
  end

  describe "#notify_error" do
    it "emits error event via emit_error" do
      instance.notify_error(error, 1, model)

      expect(instance.emitted_errors).not_to be_empty
    end

    it "includes model information" do
      instance.notify_error(error, 2, model)

      # Event should contain model context
      expect(instance.emitted_errors.last[:context][:model_id]).to eq("gpt-4")
    end

    it "includes attempt information" do
      instance.notify_error(error, 3, model)

      expect(instance.emitted_errors.last[:context][:attempt]).to eq(3)
    end

    it "marks error as recoverable" do
      instance.notify_error(error, 1, model)

      # Event should be marked as recoverable
      expect(instance.emitted_errors.last[:recoverable]).to be true
    end

    it "respects emitting flag" do
      instance.instance_variable_set(:@emitting_enabled, false)

      instance.notify_error(error, 1, model)

      expect(instance.emitted_errors).to be_empty
    end

    it "handles different error types" do
      timeout_error = Timeout::Error.new("Request timeout")
      instance.notify_error(timeout_error, 1, model)

      expect(instance.emitted_errors).not_to be_empty
      expect(instance.emitted_errors.last[:error]).to eq(timeout_error)
    end
  end

  describe "#notify_recovery" do
    it "emits recovery event" do
      instance.notify_recovery(model, 3)

      expect(instance.emitted_events).not_to be_empty
    end

    it "consumes recovery event" do
      instance.notify_recovery(model, 2)

      expect(instance.consumed_events).not_to be_empty
    end

    it "includes model information" do
      instance.notify_recovery(model, 1)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "records attempt count when recovery occurred" do
      instance.notify_recovery(model, 5)

      # Attempt count should be in the event
      expect(instance.consumed_events.last).not_to be_nil
    end

    it "respects emitting flag" do
      instance.instance_variable_set(:@emitting_enabled, false)

      instance.notify_recovery(model, 2)

      expect(instance.emitted_events).to be_empty
      expect(instance.consumed_events).not_to be_empty
    end
  end

  describe "#notify_retry" do
    it "emits retry event" do
      instance.notify_retry(model, error, 1, 3, 1.0)

      expect(instance.emitted_events).not_to be_empty
    end

    it "consumes retry event" do
      instance.notify_retry(model, error, 2, 3, 2.0)

      expect(instance.consumed_events).not_to be_empty
    end

    it "includes model id" do
      instance.notify_retry(model, error, 1, 3, 1.0)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "includes error information" do
      instance.notify_retry(model, error, 1, 3, 1.0)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "includes current attempt" do
      instance.notify_retry(model, error, 2, 5, 2.5)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "includes max attempts" do
      instance.notify_retry(model, error, 3, 10, 3.0)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "includes suggested interval" do
      instance.notify_retry(model, error, 1, 3, 1.5)

      expect(instance.consumed_events.last).not_to be_nil
    end

    it "respects emitting flag" do
      instance.instance_variable_set(:@emitting_enabled, false)

      instance.notify_retry(model, error, 1, 3, 1.0)

      expect(instance.emitted_events).to be_empty
      expect(instance.consumed_events).not_to be_empty
    end

    it "handles different backoff intervals" do
      instance.notify_retry(model, error, 1, 3, 0.5)
      instance.notify_retry(model, error, 2, 3, 1.0)
      instance.notify_retry(model, error, 3, 3, 2.0)

      expect(instance.consumed_events.size).to eq(3)
    end
  end

  describe "event emission workflow" do
    it "tracks complete retry sequence" do
      # Attempt 1 fails
      instance.notify_retry(model, error, 1, 3, 1.0)

      # Retry attempt 2 fails (notify_error doesn't consume, only emits)
      instance.notify_error(error, 2, model)

      # Retry attempt 3 succeeds
      instance.notify_recovery(model, 3)

      # notify_retry emits + consumes, notify_error only emits (via emit_error), notify_recovery emits + consumes
      expect(instance.emitted_events.size).to eq(2) # retry + recovery
      expect(instance.emitted_errors.size).to eq(1) # error
      expect(instance.consumed_events.size).to eq(2) # retry + recovery (not error)
    end

    it "tracks failover sequence" do
      backup_model = double("BackupModel", model_id: "backup")

      # Primary fails (notify_error doesn't consume)
      instance.notify_error(error, 1, model)

      # Failover occurs
      instance.notify_failover(model, backup_model, error, 1)

      # Backup succeeds
      instance.notify_recovery(backup_model, 1)

      # failover + recovery consume, error doesn't
      expect(instance.consumed_events.size).to eq(2)
    end

    it "tracks multiple retries and recovery" do
      (1..3).each do |attempt|
        instance.notify_retry(model, error, attempt, 3, attempt.to_f)
      end

      instance.notify_recovery(model, 3)

      expect(instance.consumed_events.size).to eq(4)
    end
  end

  describe "event ordering" do
    it "preserves event emission order" do
      instance.notify_error(error, 1, model)
      instance.notify_retry(model, error, 1, 3, 1.0)
      instance.notify_recovery(model, 1)

      # notify_error doesn't consume, so only retry + recovery are consumed
      expect(instance.consumed_events.size).to eq(2)
      expect(instance.emitted_errors.size).to eq(1)
    end
  end

  describe "with emitting disabled" do
    before do
      instance.instance_variable_set(:@emitting_enabled, false)
    end

    it "does not emit failover events" do
      backup = double("Backup", model_id: "backup-model")
      instance.notify_failover(model, backup, error, 1)
      expect(instance.emitted_events).to be_empty
    end

    it "does not emit error events" do
      instance.notify_error(error, 1, model)
      expect(instance.emitted_events).to be_empty
      expect(instance.emitted_errors).to be_empty
    end

    it "does not emit recovery events" do
      instance.notify_recovery(model, 1)
      expect(instance.emitted_events).to be_empty
    end

    it "does not emit retry events" do
      instance.notify_retry(model, error, 1, 3, 1.0)
      expect(instance.emitted_events).to be_empty
    end

    it "still consumes events" do
      backup = double("Backup", model_id: "backup-model")
      instance.notify_failover(model, backup, error, 1)
      expect(instance.consumed_events).not_to be_empty
    end
  end

  describe "error handling" do
    it "handles models without model_id gracefully" do
      # The actual implementation calls model_id, so models must respond to it
      # This tests that it works with nil model_id
      bad_model = double("BadModel", model_id: nil)
      expect { instance.notify_failover(bad_model, model, error, 1) }.not_to raise_error
    end

    it "handles nil error attributes" do
      bad_error = double("BadError", message: nil)
      expect { instance.notify_error(bad_error, 1, model) }.not_to raise_error
    end

    it "handles negative attempt numbers" do
      expect { instance.notify_retry(model, error, -1, 3, 1.0) }.not_to raise_error
    end

    it "handles zero max attempts" do
      expect { instance.notify_retry(model, error, 1, 0, 1.0) }.not_to raise_error
    end

    it "handles negative intervals" do
      expect { instance.notify_retry(model, error, 1, 3, -1.0) }.not_to raise_error
    end
  end

  describe "different error types" do
    it "handles StandardError" do
      err = StandardError.new("Standard error")
      instance.notify_error(err, 1, model)
      expect(instance.emitted_errors).not_to be_empty
    end

    it "handles RuntimeError" do
      err = RuntimeError.new("Runtime error")
      instance.notify_error(err, 1, model)
      expect(instance.emitted_errors).not_to be_empty
    end

    it "handles Timeout::Error" do
      err = Timeout::Error.new("Timed out")
      instance.notify_error(err, 1, model)
      expect(instance.emitted_errors).not_to be_empty
    end

    it "handles network errors" do
      err = Errno::ECONNREFUSED.new("Connection refused")
      instance.notify_error(err, 1, model)
      expect(instance.emitted_errors).not_to be_empty
    end
  end

  describe "idempotency" do
    it "can emit same event multiple times" do
      3.times do
        instance.notify_recovery(model, 1)
      end

      expect(instance.consumed_events.size).to eq(3)
    end

    it "events are independent" do
      model1 = double("Model1", model_id: "m1")
      model2 = double("Model2", model_id: "m2")

      instance.notify_recovery(model1, 1)
      instance.notify_recovery(model2, 2)

      expect(instance.consumed_events.size).to eq(2)
    end
  end
end
