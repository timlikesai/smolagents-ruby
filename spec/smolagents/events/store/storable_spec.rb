RSpec.describe Smolagents::Events::EventStore::Storable do
  let(:store) { Smolagents::Events::EventStore.new }

  # Test class that includes both Emitter and Storable
  let(:storable_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::EventStore::Storable

      def emit_test_event(step_number: 1)
        emit :step_completed, step_number:, outcome: :success
      end

      def emit_test_event_sync(step_number: 1)
        emit! :step_completed, step_number:, outcome: :success
      end
    end
  end

  let(:emitter) { storable_class.new }

  describe "without store configured" do
    it "emits events normally" do
      # No store configured, should not raise
      expect { emitter.emit_test_event }.not_to raise_error
    end
  end

  describe "with store configured" do
    before { emitter.event_store = store }

    describe "#emit" do
      it "persists events to store" do
        emitter.emit_test_event

        expect(store.count).to eq(1)
      end

      it "returns the event" do
        event = emitter.emit_test_event

        expect(event).to be_a(Smolagents::Events::StepCompleted)
      end

      it "persists events with correct data" do
        emitter.emit_test_event(step_number: 42)

        stored = store.all.first
        expect(stored.step_number).to eq(42)
      end
    end

    describe "#emit!" do
      it "persists events to store" do
        emitter.emit_test_event_sync

        expect(store.count).to eq(1)
      end
    end

    describe "#persist_to" do
      it "configures the store" do
        new_emitter = storable_class.new
        new_emitter.persist_to(store)

        new_emitter.emit_test_event

        expect(store.count).to eq(1)
      end

      it "returns self for chaining" do
        new_emitter = storable_class.new

        result = new_emitter.persist_to(store)

        expect(result).to eq(new_emitter)
      end
    end

    describe "error handling" do
      it "continues on storage errors" do
        # Create a store with a failing backend
        failing_store = instance_double(Smolagents::Events::EventStore)
        allow(failing_store).to receive(:append).and_raise("Storage error")

        emitter.event_store = failing_store

        # Should not raise despite storage failure
        expect { emitter.emit_test_event }.not_to raise_error
      end
    end

    describe "multiple events" do
      it "stores all emitted events in order" do
        emitter.emit_test_event(step_number: 1)
        emitter.emit_test_event(step_number: 2)
        emitter.emit_test_event(step_number: 3)

        expect(store.count).to eq(3)
        expect(store.all.map(&:step_number)).to eq([1, 2, 3])
      end
    end
  end

  describe "event_store accessor" do
    it "allows getting the store" do
      emitter.event_store = store

      expect(emitter.event_store).to eq(store)
    end

    it "starts as nil" do
      expect(emitter.event_store).to be_nil
    end
  end
end
