RSpec.describe Smolagents::Events::EventStore::Query do
  let(:store) { Smolagents::Events::EventStore.new }

  before do
    # Create diverse events for querying
    store.append(Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success))
    store.append(Smolagents::Events::StepCompleted.create(step_number: 2, outcome: :error))
    store.append(Smolagents::Events::TaskCompleted.create(outcome: :success, output: "done", steps_taken: 2))
  end

  describe "#type" do
    it "filters by single event type" do
      results = store.query.type(:step_completed).to_a

      expect(results.size).to eq(2)
      expect(results).to all(be_a(Smolagents::Events::StepCompleted))
    end

    it "filters by multiple event types" do
      results = store.query.type(:step_completed, :task_completed).to_a

      expect(results.size).to eq(3)
    end

    it "accepts Class as type" do
      results = store.query.type(Smolagents::Events::StepCompleted).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#since" do
    it "filters events after timestamp" do
      cutoff = store.all[0].created_at

      results = store.query.since(cutoff).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#before" do
    it "filters events before timestamp" do
      cutoff = store.all.last.created_at

      results = store.query.before(cutoff).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#between" do
    it "filters events within time range" do
      events = store.all
      range = events[0].created_at..events[1].created_at

      results = store.query.between(range).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#sequence" do
    it "filters by sequence range" do
      events = store.all
      from_seq = events[0].sequence
      to_seq = events[1].sequence

      results = store.query.sequence(from: from_seq, to: to_seq).to_a

      expect(results.size).to eq(2)
    end

    it "filters with only from" do
      from_seq = store.all[1].sequence

      results = store.query.sequence(from: from_seq).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#where" do
    it "filters with custom predicate" do
      results = store.query.where { |e| e.respond_to?(:outcome) && e.outcome == :success }.to_a

      expect(results.size).to eq(2)
    end

    it "chains with other filters" do
      results = store.query
                     .type(:step_completed)
                     .where { |e| e.step_number > 1 }
                     .to_a

      expect(results.size).to eq(1)
      expect(results.first.step_number).to eq(2)
    end
  end

  describe "#limit" do
    it "limits result count" do
      results = store.query.limit(2).to_a

      expect(results.size).to eq(2)
    end
  end

  describe "#offset" do
    it "skips first N results" do
      results = store.query.offset(1).to_a

      expect(results.size).to eq(2)
    end

    it "combines with limit" do
      results = store.query.offset(1).limit(1).to_a

      expect(results.size).to eq(1)
    end
  end

  describe "#first" do
    it "returns first matching event" do
      result = store.query.type(:step_completed).first

      expect(result.step_number).to eq(1)
    end

    it "returns nil when no matches" do
      result = store.query.where { false }.first

      expect(result).to be_nil
    end
  end

  describe "#last" do
    it "returns last matching event" do
      result = store.query.type(:step_completed).last

      expect(result.step_number).to eq(2)
    end
  end

  describe "#count" do
    it "counts matching events" do
      count = store.query.type(:step_completed).count

      expect(count).to eq(2)
    end
  end

  describe "#any?" do
    it "returns true when matches exist" do
      expect(store.query.type(:step_completed).any?).to be true
    end

    it "returns false when no matches" do
      expect(store.query.where { false }.any?).to be false
    end
  end

  describe "#none?" do
    it "returns true when no matches" do
      expect(store.query.where { false }.none?).to be true
    end

    it "returns false when matches exist" do
      expect(store.query.type(:step_completed).none?).to be false
    end
  end

  describe "#each" do
    it "yields matching events" do
      collected = []

      store.query.type(:step_completed).each { |e| collected << e }

      expect(collected.size).to eq(2)
    end

    it "returns enumerator when no block" do
      result = store.query.each

      expect(result).to be_an(Enumerator)
    end
  end

  describe "chaining" do
    it "returns Query for method chaining" do
      query = store.query
                   .type(:step_completed)
                   .where { |e| e.outcome == :success }
                   .limit(10)

      expect(query).to be_a(described_class)
    end

    it "applies all filters in chain" do
      results = store.query
                     .type(:step_completed)
                     .where { |e| e.outcome == :success }
                     .limit(5)
                     .to_a

      expect(results.size).to eq(1)
      expect(results.first.step_number).to eq(1)
    end
  end
end
