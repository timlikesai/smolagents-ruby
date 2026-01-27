RSpec.describe Smolagents::Events::EventStore::Snapshot do
  let(:snapshot) do
    described_class.new(
      sequence: 100,
      event_count: 50,
      timestamp: Time.now
    )
  end

  describe ".new" do
    it "creates immutable snapshot" do
      expect(snapshot).to be_frozen
    end

    it "stores sequence" do
      expect(snapshot.sequence).to eq(100)
    end

    it "stores event count" do
      expect(snapshot.event_count).to eq(50)
    end

    it "stores timestamp" do
      expect(snapshot.timestamp).to be_a(Time)
    end
  end

  describe "#stale?" do
    it "returns true when store has newer events" do
      expect(snapshot.stale?(150)).to be true
    end

    it "returns false when snapshot is current" do
      expect(snapshot.stale?(100)).to be false
    end

    it "returns false when snapshot is ahead" do
      expect(snapshot.stale?(50)).to be false
    end
  end

  describe "#age" do
    it "returns seconds since snapshot" do
      old_snapshot = described_class.new(
        sequence: 100,
        event_count: 50,
        timestamp: Time.now - 60
      )

      expect(old_snapshot.age).to be_within(1).of(60)
    end
  end

  describe "#to_h" do
    it "serializes to hash" do
      hash = snapshot.to_h

      expect(hash[:sequence]).to eq(100)
      expect(hash[:event_count]).to eq(50)
      expect(hash[:timestamp]).to be_a(String)
    end

    it "produces ISO8601 timestamp" do
      hash = snapshot.to_h

      expect { Time.parse(hash[:timestamp]) }.not_to raise_error
    end
  end

  describe ".from_h" do
    it "deserializes from hash" do
      hash = snapshot.to_h

      restored = described_class.from_h(hash)

      expect(restored.sequence).to eq(100)
      expect(restored.event_count).to eq(50)
      expect(restored.timestamp).to be_within(1).of(snapshot.timestamp)
    end
  end

  describe "integration with EventStore" do
    let(:store) { Smolagents::Events::EventStore.new }

    before do
      3.times do |i|
        store.append(Smolagents::Events::StepCompleted.create(step_number: i + 1, outcome: :success))
      end
    end

    it "captures store state" do
      snapshot = store.snapshot

      expect(snapshot.event_count).to eq(3)
      expect(snapshot.sequence).to eq(store.all.last.sequence)
    end

    it "enables replay from snapshot" do
      snapshot = store.snapshot

      # Add more events
      store.append(Smolagents::Events::StepCompleted.create(step_number: 4, outcome: :success))
      store.append(Smolagents::Events::StepCompleted.create(step_number: 5, outcome: :success))

      # Replay only new events
      new_events = []
      store.replay(from: snapshot.sequence + 1) { |e| new_events << e }

      expect(new_events.size).to eq(2)
      expect(new_events.map(&:step_number)).to eq([4, 5])
    end
  end
end
