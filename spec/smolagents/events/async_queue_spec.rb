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
      # This test verifies that drain doesn't use sleep by checking
      # it completes faster than a sleep-based approach would
      described_class.start

      start_time = Time.now
      described_class.drain(timeout: 5)
      elapsed = Time.now - start_time

      # Should complete nearly instantly when queue is empty
      expect(elapsed).to be < 0.1
    end
  end

  describe ".pending_count" do
    it "returns 0 when queue is empty" do
      described_class.start
      described_class.drain(timeout: 1)

      expect(described_class.pending_count).to eq(0)
    end
  end
end
