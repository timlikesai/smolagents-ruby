RSpec.describe Smolagents::Events::EventStore do
  let(:store) { described_class.new }

  def create_event(step_number: 1, outcome: :success)
    Smolagents::Events::StepCompleted.create(step_number:, outcome:)
  end

  describe "#initialize" do
    it "creates with memory backend by default" do
      expect(store.backend).to be_a(described_class::Backend::Memory)
    end

    it "creates with JSONL backend for file path" do
      path = File.join(Dir.tmpdir, "test_events_#{SecureRandom.hex(4)}.jsonl")
      file_store = described_class.new(backend: path)

      expect(file_store.backend).to be_a(described_class::Backend::JSONL)
    ensure
      file_store&.close
      FileUtils.rm_f(path)
    end
  end

  describe "#append" do
    it "appends events to the store" do
      event = create_event

      store.append(event)

      expect(store.count).to eq(1)
    end

    it "returns the appended event" do
      event = create_event

      result = store.append(event)

      expect(result).to eq(event)
    end

    it "notifies subscribers" do
      received = []
      store.subscribe { |e| received << e }
      event = create_event

      store.append(event)

      expect(received).to eq([event])
    end
  end

  describe "#replay" do
    before do
      3.times { |i| store.append(create_event(step_number: i + 1)) }
    end

    it "yields all events in order" do
      step_numbers = []

      store.replay { |e| step_numbers << e.step_number }

      expect(step_numbers).to eq([1, 2, 3])
    end

    it "replays from a specific sequence" do
      step_numbers = []
      from_seq = store.all[1].sequence

      store.replay(from: from_seq) { |e| step_numbers << e.step_number }

      expect(step_numbers).to eq([2, 3])
    end

    it "replays up to a specific sequence" do
      step_numbers = []
      to_seq = store.all[1].sequence

      store.replay(to: to_seq) { |e| step_numbers << e.step_number }

      expect(step_numbers).to eq([1, 2])
    end

    it "replays a sequence range" do
      step_numbers = []
      from_seq = store.all[0].sequence
      to_seq = store.all[1].sequence

      store.replay(from: from_seq, to: to_seq) { |e| step_numbers << e.step_number }

      expect(step_numbers).to eq([1, 2])
    end

    it "returns an enumerator when no block given" do
      result = store.replay

      expect(result).to be_an(Enumerator)
      expect(result.count).to eq(3)
    end
  end

  describe "#query" do
    before do
      store.append(Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success))
      store.append(Smolagents::Events::StepCompleted.create(step_number: 2, outcome: :error))
      store.append(Smolagents::Events::TaskLifecycle.create(phase: :completed, outcome: :success, output: "done",
                                                            steps_taken: 2))
    end

    it "returns a Query object" do
      expect(store.query).to be_a(described_class::Query)
    end

    it "filters by type" do
      results = store.query.type(:step_completed).to_a

      expect(results.size).to eq(2)
      expect(results).to all(be_a(Smolagents::Events::StepCompleted))
    end

    it "filters by multiple types" do
      results = store.query.type(:step_completed, :task_lifecycle).to_a

      expect(results.size).to eq(3)
    end

    it "chains filters with where" do
      results = store.query
                     .type(:step_completed)
                     .where { |e| e.outcome == :success }
                     .to_a

      expect(results.size).to eq(1)
      expect(results.first.step_number).to eq(1)
    end
  end

  describe "#snapshot" do
    it "captures current state" do
      store.append(create_event)
      store.append(create_event(step_number: 2))

      snapshot = store.snapshot

      expect(snapshot.event_count).to eq(2)
      expect(snapshot.sequence).to eq(store.all.last.sequence)
    end

    it "returns a Snapshot type" do
      store.append(create_event)

      snapshot = store.snapshot

      expect(snapshot).to be_a(described_class::Snapshot)
      expect(snapshot).to be_frozen
    end
  end

  describe "#subscribe" do
    it "registers multiple subscribers" do
      received1 = []
      received2 = []

      store.subscribe { |e| received1 << e }
      store.subscribe { |e| received2 << e }
      event = create_event
      store.append(event)

      expect(received1).to eq([event])
      expect(received2).to eq([event])
    end

    it "continues on subscriber errors" do
      store.subscribe { |_e| raise "boom" }
      received = []
      store.subscribe { |e| received << e }

      event = create_event
      store.append(event)

      expect(received).to eq([event])
    end
  end

  describe "#unsubscribe_all" do
    it "clears all subscribers" do
      received = []
      store.subscribe { |e| received << e }
      store.unsubscribe_all

      store.append(create_event)

      expect(received).to be_empty
    end
  end

  describe "#count" do
    it "returns zero for empty store" do
      expect(store.count).to eq(0)
    end

    it "returns count of stored events" do
      store.append(create_event)
      store.append(create_event(step_number: 2))

      expect(store.count).to eq(2)
    end
  end

  describe "#all" do
    it "returns copy of all events" do
      event1 = create_event
      event2 = create_event(step_number: 2)
      store.append(event1)
      store.append(event2)

      result = store.all

      expect(result).to eq([event1, event2])
      expect(result).not_to be(store.all) # It's a copy
    end
  end
end
