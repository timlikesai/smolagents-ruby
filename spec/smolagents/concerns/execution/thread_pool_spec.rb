require "smolagents/concerns/execution/thread_pool"

RSpec.describe Smolagents::Concerns::ThreadPool do
  describe "#initialize" do
    it "stores configuration" do
      pool = described_class.new(4)

      expect(pool).to be_a(described_class)
      expect(pool.instance_variable_get(:@max_threads)).to eq(4)
      expect(pool.instance_variable_get(:@mutex)).to be_a(Mutex)
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

  describe "max_threads behavior" do
    it "is informational only - allows exceeding limit" do
      pool = described_class.new(2)

      # 3 threads proves we can exceed max_threads=2
      threads = Array.new(3) { pool.spawn { "work" } }

      expect(threads.size).to eq(3)
      threads.each(&:join)
    end
  end
end
