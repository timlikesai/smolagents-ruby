require "spec_helper"

RSpec.describe Smolagents::Concerns::Orchestration::WorkerPool do
  let(:pool_host) do
    Class.new do
      include Smolagents::Concerns::Orchestration::WorkerPool
    end.new
  end

  after do
    pool_host.shutdown_pool if pool_host.pool_running?
  end

  describe "#init_worker_pool" do
    it "initializes with default size" do
      pool_host.init_worker_pool

      expect(pool_host.pool_size).to be >= 2
      expect(pool_host.pool_size).to be <= 8
    end

    it "accepts custom size" do
      pool_host.init_worker_pool(size: 3)

      expect(pool_host.pool_size).to eq(3)
    end

    it "starts in stopped state" do
      pool_host.init_worker_pool

      expect(pool_host.pool_running?).to be false
    end
  end

  describe "#start_pool" do
    before { pool_host.init_worker_pool(size: 2) }

    it "starts worker threads" do
      pool_host.start_pool

      expect(pool_host.pool_running?).to be true
      expect(pool_host.active_workers).to eq(2)
    end

    it "is idempotent" do
      pool_host.start_pool
      pool_host.start_pool

      expect(pool_host.active_workers).to eq(2)
    end

    it "returns self for chaining" do
      expect(pool_host.start_pool).to eq(pool_host)
    end
  end

  describe "#shutdown_pool" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "stops all workers" do
      # shutdown_pool blocks until workers exit (via thread.join)
      pool_host.shutdown_pool

      expect(pool_host.pool_running?).to be false
      expect(pool_host.active_workers).to eq(0)
    end

    it "returns self for chaining" do
      expect(pool_host.shutdown_pool).to eq(pool_host)
    end

    it "is idempotent" do
      pool_host.shutdown_pool
      pool_host.shutdown_pool

      expect(pool_host.pool_running?).to be false
    end
  end

  describe "#submit" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "executes work" do
      result_queue = Thread::Queue.new
      pool_host.submit { result_queue.push(42) }

      expect(result_queue.pop).to eq(42)
    end

    it "accepts proc or block" do
      result_queue = Thread::Queue.new
      pool_host.submit(-> { result_queue.push(1) })
      pool_host.submit { result_queue.push(2) }

      results = [result_queue.pop, result_queue.pop]
      expect(results).to contain_exactly(1, 2)
    end

    it "raises when pool not running" do
      pool_host.shutdown_pool

      expect { pool_host.submit { 42 } }
        .to raise_error(Smolagents::Concerns::Orchestration::WorkerPool::PoolNotRunningError)
    end

    it "requires work" do
      expect { pool_host.submit }
        .to raise_error(ArgumentError, /Work required/)
    end
  end

  describe "#submit_batch" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "submits multiple work items" do
      result_queue = Thread::Queue.new
      mutex = Mutex.new

      items = Array.new(3) do |i|
        -> { mutex.synchronize { result_queue.push(i) } }
      end

      pool_host.submit_batch(items)

      # Collect all 3 results
      results = Array.new(3) { result_queue.pop }
      expect(results.sort).to eq([0, 1, 2])
    end
  end

  describe "#submit_async" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "calls on_complete with result" do
      result_queue = Thread::Queue.new
      pool_host.submit_async(on_complete: ->(r) { result_queue.push(r) }) { 42 }

      expect(result_queue.pop).to eq(42)
    end

    it "calls on_error on failure" do
      error_queue = Thread::Queue.new
      pool_host.submit_async(on_error: ->(e) { error_queue.push(e) }) do
        raise StandardError, "Failed"
      end

      error = error_queue.pop
      expect(error).to be_a(StandardError)
      expect(error.message).to eq("Failed")
    end
  end

  describe "#scale_pool" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "increases pool size" do
      pool_host.scale_pool(4)

      expect(pool_host.pool_size).to eq(4)
      expect(pool_host.active_workers).to eq(4)
    end

    it "decreases pool size" do
      pool_host.scale_pool(1)

      expect(pool_host.pool_size).to eq(1)
      # Workers will shut down gradually via shutdown signals
    end
  end

  describe "#pool_stats" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "returns statistics hash", :slow do
      stats = pool_host.pool_stats

      expect(stats).to include(
        :size,
        :active,
        :pending,
        :completed,
        :errors,
        :running
      )
    end

    it "tracks completed work" do
      done_queue = Thread::Queue.new

      3.times { pool_host.submit { done_queue.push(:done) } }

      # Wait for all 3 to complete
      3.times { done_queue.pop }

      expect(pool_host.pool_stats[:completed]).to be >= 3
    end

    it "tracks errors" do
      error_queue = Thread::Queue.new

      pool_host.submit_async(on_error: ->(e) { error_queue.push(e) }) do
        raise StandardError, "test error"
      end

      error_queue.pop # Wait for error to be processed
      expect(pool_host.pool_stats[:errors]).to be >= 1
    end
  end

  describe "thread safety" do
    before do
      pool_host.init_worker_pool(size: 4)
      pool_host.start_pool
    end

    it "handles concurrent submissions" do
      done_queue = Thread::Queue.new
      counter = 0
      mutex = Mutex.new
      total_work_items = 100

      threads = Array.new(10) do
        Thread.new do
          10.times do
            pool_host.submit do
              mutex.synchronize { counter += 1 }
              done_queue.push(:done)
            end
          end
        end
      end

      threads.each(&:join)

      # Wait for all work items to complete
      total_work_items.times { done_queue.pop }

      expect(counter).to eq(100)
    end
  end
end
