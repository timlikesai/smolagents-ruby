require "smolagents/concerns/execution/thread_pool"

RSpec.describe Smolagents::Concerns::ThreadPool do
  describe "#initialize" do
    it "stores configuration" do
      pool = described_class.new(4)

      expect(pool).to be_a(described_class)
      expect(pool.instance_variable_get(:@max_threads)).to eq(4)
      expect(pool.instance_variable_get(:@mutex)).to be_a(Mutex)
      expect(pool.instance_variable_get(:@condition)).to be_a(ConditionVariable)
      expect(pool.instance_variable_get(:@active)).to eq(0)
    end
  end

  describe "#spawn" do
    let(:pool) { described_class.new(4) }

    it "returns a Thread that executes the block" do
      executed = false
      thread = pool.spawn { executed = true }

      expect(thread).to be_a(Thread)
      thread.join
      expect(executed).to be true
    end

    it "returns value from block" do
      thread = pool.spawn { 42 }
      expect(thread.value).to eq(42)
    end

    it "propagates exceptions" do
      thread = pool.spawn { raise StandardError, "boom" }
      expect { thread.value }.to raise_error(StandardError, "boom")
    end

    it "tracks active count during execution" do
      # Use Queue for deterministic coordination
      hold = Thread::Queue.new
      started = Thread::Queue.new

      thread = pool.spawn do
        started.push(:ready)
        hold.pop
      end

      started.pop # Wait for thread to start
      expect(pool.instance_variable_get(:@active)).to eq(1)

      hold.push(:done)
      thread.join
      expect(pool.instance_variable_get(:@active)).to eq(0)
    end

    it "tracks active count even when block raises" do
      thread = pool.spawn { raise "error" }
      begin
        thread.join
      rescue StandardError
        nil
      end

      expect(pool.instance_variable_get(:@active)).to eq(0)
    end
  end

  describe "thread safety" do
    it "correctly tracks multiple concurrent threads" do
      pool = described_class.new(4)

      # Only need 3 threads to verify concurrency, not 10+
      holds = Array.new(3) { Thread::Queue.new }
      started = Thread::Queue.new

      threads = holds.map do |hold|
        pool.spawn do
          started.push(:ready)
          hold.pop
        end
      end

      # Wait for all to start
      3.times { started.pop }
      expect(pool.instance_variable_get(:@active)).to eq(3)

      # Release and verify cleanup
      holds.each { |h| h.push(:done) }
      threads.each(&:join)
      expect(pool.instance_variable_get(:@active)).to eq(0)
    end
  end

  describe "max_threads enforcement" do
    it "blocks spawn when max_threads is reached" do
      pool = described_class.new(2)

      # Use queues for deterministic coordination
      holds = Array.new(2) { Thread::Queue.new }
      started = Thread::Queue.new
      third_spawned = Thread::Queue.new

      # Fill the pool to max_threads
      threads = holds.map do |hold|
        pool.spawn do
          started.push(:ready)
          hold.pop
        end
      end

      # Wait for both to start
      2.times { started.pop }
      expect(pool.instance_variable_get(:@active)).to eq(2)

      # Try to spawn a third - should block
      third_thread = Thread.new do
        third_spawned.push(:attempting)
        pool.spawn { :third_done }
      end

      # Wait for attempt to start, then verify it's blocked
      third_spawned.pop
      sleep 0.05 # Give time for spawn to potentially proceed
      expect(pool.instance_variable_get(:@active)).to eq(2)
      expect(third_thread.status).to eq("sleep") # Blocked waiting

      # Release one slot - third should now proceed
      holds.first.push(:done)
      threads.first.join

      # Third should complete
      spawned_thread = third_thread.value
      spawned_thread.join

      # Clean up remaining
      holds.last.push(:done)
      threads.last.join
    end

    it "allows spawning up to max_threads concurrently" do
      pool = described_class.new(3)

      holds = Array.new(3) { Thread::Queue.new }
      started = Thread::Queue.new

      threads = holds.map do |hold|
        pool.spawn do
          started.push(:ready)
          hold.pop
        end
      end

      # All 3 should start without blocking
      3.times { started.pop }
      expect(pool.instance_variable_get(:@active)).to eq(3)

      # Clean up
      holds.each { |h| h.push(:done) }
      threads.each(&:join)
    end

    it "releases slots correctly enabling queued spawns" do
      pool = described_class.new(1)
      results = Thread::Queue.new

      # First thread takes the slot
      hold = Thread::Queue.new
      first = pool.spawn do
        hold.pop
        results.push(:first)
      end

      # Second spawn will block until first completes
      second_spawner = Thread.new do
        pool.spawn { results.push(:second) }
      end

      sleep 0.05 # Let second_spawner block
      expect(second_spawner.status).to eq("sleep")

      # Release first, which should unblock second
      hold.push(:go)
      first.join

      second = second_spawner.value
      second.join

      # Both completed in order
      expect(results.pop).to eq(:first)
      expect(results.pop).to eq(:second)
    end
  end
end
