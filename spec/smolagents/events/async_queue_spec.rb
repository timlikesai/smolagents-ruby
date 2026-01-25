require "spec_helper"

RSpec.describe Smolagents::Events::AsyncQueue do
  before { described_class.reset! }
  after { described_class.reset! }

  describe ".start / .running? / .shutdown" do
    it "manages worker lifecycle" do
      expect(described_class.running?).to be false

      thread = described_class.start
      expect(thread).to be_a(Thread)
      expect(described_class.running?).to be true

      # Idempotent
      expect(described_class.start).to eq(thread)

      expect(described_class.shutdown(timeout: 1)).to be true
      expect(described_class.running?).to be false
    end

    it "reinitializes after reset" do
      described_class.start
      described_class.reset!
      expect(described_class.start).to be_alive
    end
  end

  describe ".push" do
    it "processes events asynchronously" do
      results = []
      mutex = Mutex.new

      described_class.push("a") { |e| mutex.synchronize { results << e } }
      described_class.push("b") { |e| mutex.synchronize { results << e } }
      described_class.drain(timeout: 1)

      expect(results).to contain_exactly("a", "b")
    end

    it "auto-starts worker if not running" do
      expect(described_class.running?).to be false
      described_class.push("event") { nil }
      expect(described_class.running?).to be true
    end

    it "handles handler errors gracefully" do
      expect do
        described_class.push("bad") { raise "boom" }
        described_class.drain(timeout: 1)
      end.to output(/AsyncQueue error/).to_stderr

      expect(described_class.running?).to be true
    end

    it "processes events in order" do
      results = []
      mutex = Mutex.new

      3.times { |i| described_class.push(i) { |e| mutex.synchronize { results << e } } }
      described_class.drain(timeout: 1)

      expect(results).to eq([0, 1, 2])
    end
  end

  describe ".drain" do
    it "waits for events using ConditionVariable (fast return)" do
      described_class.start

      start_time = Time.now
      described_class.drain(timeout: 5)
      elapsed = Time.now - start_time

      # Should return immediately since queue is empty
      expect(elapsed).to be < 0.05
    end

    it "returns true when not running" do
      expect(described_class.drain(timeout: 1)).to be true
    end
  end

  describe ".pending_count" do
    it "returns 0 in all idle states" do
      expect(described_class.pending_count).to eq(0) # not started

      described_class.start
      described_class.drain(timeout: 1)
      expect(described_class.pending_count).to eq(0) # started, empty

      described_class.shutdown(timeout: 1)
      expect(described_class.pending_count).to eq(0) # shutdown
    end
  end

  describe "DrainSignal" do
    let(:signal) { described_class::DrainSignal.new }

    it "coordinates completion between threads" do
      expect(signal.wait(0.01)).to be false

      signal.complete!
      expect(signal.wait(0.01)).to be true

      # Idempotent
      expect { signal.complete! }.not_to raise_error
    end

    it "wakes waiter when complete! called from another thread" do
      result_queue = Thread::Queue.new
      started = Thread::Queue.new

      waiter = Thread.new do
        started.push(:ready)
        result_queue.push(signal.wait(2))
      end

      started.pop # Wait for waiter to start
      signal.complete!

      # Block until result arrives (proves signal woke the waiter)
      expect(result_queue.pop).to be true
      waiter.join
    end
  end

  describe "thread safety" do
    it "handles concurrent pushes from multiple threads" do
      results = []
      mutex = Mutex.new

      # 2 threads, 3 events each = 6 total (minimal to prove concurrency)
      threads = Array.new(2) do |i|
        Thread.new do
          3.times { |j| described_class.push("#{i}-#{j}") { |e| mutex.synchronize { results << e } } }
        end
      end

      threads.each(&:join)
      described_class.drain(timeout: 1)

      expect(results.size).to eq(6)
    end
  end
end
