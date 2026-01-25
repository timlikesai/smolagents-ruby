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

    it "returns self for chaining", :slow do
      expect(pool_host.start_pool).to eq(pool_host)
    end
  end

  describe "#shutdown_pool" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "stops all workers", :slow do
      pool_host.shutdown_pool

      expect(pool_host.pool_running?).to be false
      sleep 0.1 # rubocop:disable Smolagents/NoSleep -- wait for threads to exit
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

  describe "#submit", :slow do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "executes work" do
      result = nil
      pool_host.submit { result = 42 }
      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(result).to eq(42)
    end

    it "accepts proc or block" do
      results = []
      pool_host.submit(-> { results << 1 })
      pool_host.submit { results << 2 }
      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- wait for execution

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

  describe "#submit_batch", :slow do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "submits multiple work items" do
      results = []
      mutex = Mutex.new

      items = Array.new(3) do |i|
        -> { mutex.synchronize { results << i } }
      end

      pool_host.submit_batch(items)
      sleep 0.1 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(results.sort).to eq([0, 1, 2])
    end
  end

  describe "#submit_async", :slow do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "calls on_complete with result" do
      completed_result = nil
      pool_host.submit_async(on_complete: ->(r) { completed_result = r }) { 42 }
      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(completed_result).to eq(42)
    end

    it "calls on_error on failure" do
      error_caught = nil
      pool_host.submit_async(on_error: ->(e) { error_caught = e }) do
        raise StandardError, "Failed"
      end
      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(error_caught).to be_a(StandardError)
      expect(error_caught.message).to eq("Failed")
    end
  end

  describe "#scale_pool", :slow do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "increases pool size" do
      pool_host.scale_pool(4)

      expect(pool_host.pool_size).to eq(4)
      sleep 0.05 # rubocop:disable Smolagents/NoSleep -- wait for new workers
      expect(pool_host.active_workers).to eq(4)
    end

    it "decreases pool size" do
      pool_host.scale_pool(1)

      expect(pool_host.pool_size).to eq(1)
      # Workers will shut down gradually
    end
  end

  describe "#pool_stats" do
    before do
      pool_host.init_worker_pool(size: 2)
      pool_host.start_pool
    end

    it "returns statistics hash" do
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

    it "tracks completed work", :slow do
      3.times { pool_host.submit { 1 + 1 } }
      sleep 0.1 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(pool_host.pool_stats[:completed]).to be >= 3
    end

    it "tracks errors", :slow do
      pool_host.submit { raise StandardError }
      sleep 0.1 # rubocop:disable Smolagents/NoSleep -- wait for execution

      expect(pool_host.pool_stats[:errors]).to be >= 1
    end
  end

  describe "thread safety" do
    before do
      pool_host.init_worker_pool(size: 4)
      pool_host.start_pool
    end

    it "handles concurrent submissions", :slow do
      counter = 0
      mutex = Mutex.new

      threads = Array.new(10) do
        Thread.new do
          10.times { pool_host.submit { mutex.synchronize { counter += 1 } } }
        end
      end

      threads.each(&:join)
      sleep 0.15 # rubocop:disable Smolagents/NoSleep -- wait for completion

      expect(counter).to eq(100)
    end
  end
end
