RSpec.describe Smolagents::Events::EventStore::Backend do
  def create_event(step_number: 1)
    Smolagents::Events::StepCompleted.create(step_number:, outcome: :success)
  end

  describe ".for" do
    it "creates Memory backend for :memory" do
      backend = described_class.for(:memory)

      expect(backend).to be_a(described_class::Memory)
    end

    it "creates JSONL backend for string path" do
      backend = described_class.for("/tmp/events.jsonl")

      expect(backend).to be_a(described_class::JSONL)
    end

    it "raises for unknown backend" do
      expect { described_class.for(:postgres) }.to raise_error(ArgumentError, /Unknown backend/)
    end
  end

  describe described_class::Memory do
    let(:backend) { described_class.new }

    describe "#append" do
      it "stores events" do
        event = create_event

        backend.append(event)

        expect(backend.count).to eq(1)
      end

      it "returns the event" do
        event = create_event

        result = backend.append(event)

        expect(result).to eq(event)
      end
    end

    describe "#events_in_range" do
      before do
        3.times { |i| backend.append(create_event(step_number: i + 1)) }
      end

      it "returns all events when no bounds" do
        events = backend.events_in_range(0, nil)

        expect(events.size).to eq(3)
      end

      it "filters by from sequence" do
        from_seq = backend.all[1].sequence

        events = backend.events_in_range(from_seq, nil)

        expect(events.size).to eq(2)
      end

      it "filters by to sequence" do
        to_seq = backend.all[1].sequence

        events = backend.events_in_range(0, to_seq)

        expect(events.size).to eq(2)
      end
    end

    describe "#last_sequence" do
      it "returns 0 for empty backend" do
        expect(backend.last_sequence).to eq(0)
      end

      it "returns last event sequence" do
        backend.append(create_event)
        event = backend.append(create_event(step_number: 2))

        expect(backend.last_sequence).to eq(event.sequence)
      end
    end

    describe "#clear" do
      it "removes all events" do
        backend.append(create_event)
        backend.append(create_event(step_number: 2))

        backend.clear

        expect(backend.count).to eq(0)
      end
    end

    describe "max_events" do
      let(:bounded_backend) { described_class.new(max_events: 3) }

      it "drops oldest events when exceeding max" do
        4.times { |i| bounded_backend.append(create_event(step_number: i + 1)) }

        expect(bounded_backend.count).to eq(3)
        expect(bounded_backend.all.first.step_number).to eq(2)
        expect(bounded_backend.all.last.step_number).to eq(4)
      end

      it "allows unbounded when max_events is nil" do
        unbounded = described_class.new(max_events: nil)

        10.times { |i| unbounded.append(create_event(step_number: i + 1)) }

        expect(unbounded.count).to eq(10)
      end

      it "keeps exactly max_events items" do
        10.times { |i| bounded_backend.append(create_event(step_number: i + 1)) }

        expect(bounded_backend.count).to eq(3)
        expect(bounded_backend.all.map(&:step_number)).to eq([8, 9, 10])
      end
    end
  end

  describe described_class::JSONL do
    let(:path) { File.join(Dir.tmpdir, "test_events_#{SecureRandom.hex(4)}.jsonl") }
    let(:backend) { described_class.new(path) }

    after do
      backend.close
      FileUtils.rm_f(path)
    end

    describe "#append" do
      it "persists events to file after flush" do
        event = create_event

        backend.append(event)
        backend.flush

        expect(File.read(path)).to include(event.id)
      end

      it "appends as JSONL format" do
        backend.append(create_event)
        backend.append(create_event(step_number: 2))
        backend.flush

        lines = File.readlines(path)
        expect(lines.size).to eq(2)
        expect { JSON.parse(lines.first) }.not_to raise_error
      end

      it "in-memory index is instant" do
        event = create_event
        backend.append(event)

        expect(backend.count).to eq(1)
        expect(backend.all.first).to eq(event)
      end
    end

    describe "#load" do
      it "loads events from existing file" do
        event = create_event
        backend.append(event)
        backend.close

        new_backend = described_class.new(path)
        new_backend.load

        expect(new_backend.count).to eq(1)
        expect(new_backend.all.first.id).to eq(event.id)
      ensure
        new_backend&.close
      end

      it "handles empty file" do
        FileUtils.touch(path)

        new_backend = described_class.new(path)
        new_backend.load

        expect(new_backend.count).to eq(0)
      ensure
        new_backend&.close
      end

      it "handles missing file gracefully" do
        new_backend = described_class.new("/nonexistent/path/events.jsonl")
        new_backend.load

        expect(new_backend.count).to eq(0)
      end
    end

    describe "#events_in_range" do
      before do
        3.times { |i| backend.append(create_event(step_number: i + 1)) }
      end

      it "filters by sequence range" do
        from_seq = backend.all[1].sequence

        events = backend.events_in_range(from_seq, nil)

        expect(events.size).to eq(2)
      end
    end

    describe "#flush" do
      it "synchronously drains pending writes" do
        3.times { |i| backend.append(create_event(step_number: i + 1)) }
        backend.flush

        lines = File.readlines(path)
        expect(lines.size).to eq(3)
      end

      it "is idempotent when queue is empty" do
        backend.flush

        expect(File.exist?(path)).to be false
      end
    end

    describe "#close" do
      it "flushes all pending writes to disk" do
        event = create_event
        backend.append(event)
        backend.close

        content = File.read(path)
        expect(content).to include(event.id)
      end

      it "stops the background writer thread" do
        backend.append(create_event)
        backend.close

        expect(Thread.list.none? { |t| t.name == "JSONL-Writer" }).to be true
      end

      it "can be called multiple times" do
        backend.append(create_event)
        backend.close

        expect { backend.close }.not_to raise_error
      end
    end

    describe "max_events" do
      let(:bounded_path) { File.join(Dir.tmpdir, "bounded_events_#{SecureRandom.hex(4)}.jsonl") }
      let(:bounded_backend) { described_class.new(bounded_path, max_events: 3) }

      after do
        bounded_backend.close
        FileUtils.rm_f(bounded_path)
      end

      it "bounds in-memory index" do
        5.times { |i| bounded_backend.append(create_event(step_number: i + 1)) }

        expect(bounded_backend.count).to eq(3)
        expect(bounded_backend.all.first.step_number).to eq(3)
      end

      it "persists all events to disk" do
        5.times { |i| bounded_backend.append(create_event(step_number: i + 1)) }
        bounded_backend.flush

        lines = File.readlines(bounded_path)
        expect(lines.size).to eq(5)
      end
    end

    describe "event reconstruction" do
      it "preserves event timestamps" do
        event = create_event
        backend.append(event)
        backend.close

        new_backend = described_class.new(path)
        new_backend.load
        loaded = new_backend.all.first

        expect(loaded.created_at).to be_within(1).of(event.created_at)
      ensure
        new_backend&.close
      end

      it "preserves event data" do
        event = Smolagents::Events::TaskLifecycle.create(
          phase: :completed,
          outcome: :success,
          output: "Hello, World!",
          steps_taken: 5
        )
        backend.append(event)
        backend.close

        new_backend = described_class.new(path)
        new_backend.load
        loaded = new_backend.all.first

        expect(loaded.outcome).to eq(:success)
        expect(loaded.output).to eq("Hello, World!")
        expect(loaded.steps_taken).to eq(5)
      ensure
        new_backend&.close
      end
    end
  end
end
