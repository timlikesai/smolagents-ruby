require "spec_helper"

RSpec.describe Smolagents::Events::AsyncQueue do
  after do
    described_class.reset!
  end

  describe ".start" do
    it "starts the background worker" do
      described_class.start

      expect(described_class.running?).to be true
    end

    it "returns the worker thread" do
      thread = described_class.start

      expect(thread).to be_a(Thread)
      expect(thread).to be_alive
    end

    it "is idempotent" do
      thread1 = described_class.start
      thread2 = described_class.start

      expect(thread1).to eq(thread2)
    end

    it "reinitializes after reset" do
      described_class.start
      described_class.reset!

      thread = described_class.start
      expect(thread).to be_alive
    end
  end

  describe ".push" do
    it "processes events asynchronously" do
      results = []
      mutex = Mutex.new

      described_class.push("event1") { |e| mutex.synchronize { results << e } }
      described_class.push("event2") { |e| mutex.synchronize { results << e } }

      described_class.drain(timeout: 1)

      expect(results).to contain_exactly("event1", "event2")
    end

    it "auto-starts worker if not running" do
      expect(described_class.running?).to be false

      described_class.push("event") { nil }

      expect(described_class.running?).to be true
    end

    it "handles handler errors gracefully" do
      described_class.push("bad") { raise "boom" }
      described_class.push("good") { "ok" }

      described_class.drain(timeout: 1)

      expect(described_class.running?).to be true
    end

    it "outputs warning when handler raises" do
      expect do
        described_class.push("bad_event") { raise StandardError, "test error" }
        described_class.drain(timeout: 1)
      end.to output(/AsyncQueue error processing String: test error/).to_stderr
    end

    it "handles nil handler gracefully" do
      described_class.push("event_without_handler")
      described_class.drain(timeout: 1)

      expect(described_class.running?).to be true
    end

    it "processes events in order" do
      results = []
      mutex = Mutex.new

      10.times { |i| described_class.push(i) { |e| mutex.synchronize { results << e } } }
      described_class.drain(timeout: 1)

      expect(results).to eq((0..9).to_a)
    end
  end

  describe ".shutdown" do
    it "stops the worker thread" do
      described_class.start

      result = described_class.shutdown(timeout: 1)

      expect(result).to be true
      expect(described_class.running?).to be false
    end

    it "processes pending events before shutdown" do
      results = []
      mutex = Mutex.new

      5.times { |i| described_class.push(i) { |e| mutex.synchronize { results << e } } }
      described_class.shutdown(timeout: 2)

      expect(results.sort).to eq([0, 1, 2, 3, 4])
    end

    it "returns true when not running" do
      expect(described_class.shutdown).to be true
    end

    it "cleans up queue and worker references" do
      described_class.start
      described_class.shutdown(timeout: 1)

      expect(described_class.pending_count).to eq(0)
    end

    it "can be called multiple times safely" do
      described_class.start
      described_class.shutdown(timeout: 1)

      expect(described_class.shutdown(timeout: 1)).to be true
    end
  end

  describe ".running?" do
    it "returns false when not started" do
      expect(described_class.running?).to be false
    end

    it "returns true when started" do
      described_class.start

      expect(described_class.running?).to be true
    end

    it "returns false after shutdown" do
      described_class.start
      described_class.shutdown(timeout: 1)

      expect(described_class.running?).to be false
    end
  end

  describe ".drain" do
    it "waits for all events to be processed" do
      results = []
      mutex = Mutex.new

      3.times { |i| described_class.push(i) { |e| mutex.synchronize { results << e } } }

      expect(described_class.drain(timeout: 1)).to be true
      expect(results).to contain_exactly(0, 1, 2)
    end

    it "returns true immediately when not running" do
      expect(described_class.drain(timeout: 1)).to be true
    end

    it "uses ConditionVariable for synchronization" do
      described_class.start

      start_time = Time.now
      described_class.drain(timeout: 5)
      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.1
    end

    it "handles multiple sequential drains" do
      results = []
      mutex = Mutex.new

      described_class.push(1) { |e| mutex.synchronize { results << e } }
      described_class.drain(timeout: 1)

      described_class.push(2) { |e| mutex.synchronize { results << e } }
      described_class.drain(timeout: 1)

      expect(results).to eq([1, 2])
    end

    it "returns true when queue is empty and running" do
      described_class.start

      expect(described_class.drain(timeout: 1)).to be true
    end
  end

  describe ".pending_count" do
    it "returns 0 when queue is empty" do
      described_class.start
      described_class.drain(timeout: 1)

      expect(described_class.pending_count).to eq(0)
    end

    it "returns 0 when not started" do
      expect(described_class.pending_count).to eq(0)
    end

    it "returns 0 after shutdown" do
      described_class.start
      described_class.shutdown(timeout: 1)

      expect(described_class.pending_count).to eq(0)
    end
  end

  describe ".reset!" do
    it "shuts down and clears mutex" do
      described_class.start
      expect(described_class.running?).to be true

      described_class.reset!

      expect(described_class.running?).to be false
    end

    it "allows fresh start after reset" do
      described_class.start
      described_class.reset!
      described_class.start

      expect(described_class.running?).to be true
    end

    it "is safe to call when not started" do
      expect { described_class.reset! }.not_to raise_error
    end
  end

  describe "DrainSignal" do
    let(:signal) { Smolagents::Events::AsyncQueue::DrainSignal.new }

    describe "#complete!" do
      it "signals completion" do
        expect(signal.wait(0.01)).to be false

        signal.complete!

        expect(signal.wait(0.01)).to be true
      end

      it "can be called multiple times safely" do
        signal.complete!
        expect { signal.complete! }.not_to raise_error
      end
    end

    describe "#wait" do
      it "returns false on timeout when not complete" do
        expect(signal.wait(0.01)).to be false
      end

      it "returns true immediately when already complete" do
        signal.complete!

        start_time = Time.now
        result = signal.wait(5)
        elapsed = Time.now - start_time

        expect(result).to be true
        expect(elapsed).to be < 0.1
      end

      it "wakes up when complete! is called from another thread" do
        result = nil

        waiter = Thread.new { result = signal.wait(2) }
        sleep 0.01 # rubocop:disable Smolagents/NoSleep -- brief delay for thread coordination
        signal.complete!
        waiter.join(1)

        expect(result).to be true
      end
    end
  end

  describe "thread safety" do
    it "handles concurrent pushes" do
      results = []
      mutex = Mutex.new

      threads = Array.new(5) do |i|
        Thread.new do
          10.times do |j|
            described_class.push("#{i}-#{j}") { |e| mutex.synchronize { results << e } }
          end
        end
      end

      threads.each(&:join)
      described_class.drain(timeout: 2)

      expect(results.size).to eq(50)
    end

    it "handles concurrent start calls" do
      threads = Array.new(10) do
        Thread.new { described_class.start }
      end

      threads.each(&:join)

      # All concurrent starts should leave exactly one worker running
      expect(described_class.running?).to be true
    end
  end

  describe "edge cases" do
    it "handles empty event" do
      results = []

      described_class.push(nil) { |e| results << e }
      described_class.drain(timeout: 1)

      expect(results).to eq([nil])
    end

    it "handles complex event objects" do
      event = { type: "test", data: { nested: [1, 2, 3] } }
      results = []

      described_class.push(event) { |e| results << e }
      described_class.drain(timeout: 1)

      expect(results).to eq([event])
    end
  end
end
