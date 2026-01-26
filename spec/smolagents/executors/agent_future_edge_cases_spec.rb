require "spec_helper"

# Edge case tests for AgentFuture
#
# Covers scenarios not fully tested in agent_future_spec.rb:
# - Concurrent access patterns
# - Error propagation after cancellation
# - Value access on cancelled/timed-out futures
# - Duration tracking edge cases
RSpec.describe Smolagents::Executors::AgentFuture do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_result) { instance_double(Smolagents::Types::RunResult, output: "test result") }

  let(:mock_agent) do
    agent = instance_double(Smolagents::Agents::Agent)
    allow(agent).to receive(:run).and_return(mock_result)
    agent
  end

  describe "concurrent access" do
    it "handles multiple threads calling value simultaneously" do
      ready_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        ready_queue.pop # Wait for signal
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      # Start multiple reader threads
      readers = 3.times.map do
        Thread.new { future.value }
      end

      # Let the agent complete
      ready_queue.push(:go)

      # All readers should get the same result
      results = readers.map(&:value)
      expect(results).to all(eq("test result"))
    end

    it "prevents race condition in cancel! while running" do
      started_queue = Thread::Queue.new
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        started_queue.push(:started)
        blocking_queue.pop # Wait until cancelled or signaled
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      # Wait for agent to start
      started_queue.pop

      # Cancel from multiple threads simultaneously
      cancel_results = 3.times.map do
        Thread.new { future.cancel! }
      end.map(&:value)

      # Only one cancel should succeed
      expect(cancel_results.count(true)).to eq(1)
      expect(cancel_results.count(false)).to eq(2)
      expect(future.cancelled?).to be true
    end

    it "handles execute! idempotency under concurrent calls" do
      call_count = 0
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        call_count += 1
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")

      # Try to execute from multiple threads
      threads = 5.times.map do
        Thread.new { future.execute! }
      end
      threads.each(&:join)
      future.value # Wait for completion

      # Agent should only be called once
      expect(call_count).to eq(1)
    end
  end

  describe "error propagation after cancellation" do
    it "raises CancellationError when calling value on cancelled future" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect { future.value }.to raise_error(Smolagents::Executors::CancellationError)
    end

    it "returns nil from value_or_nil on cancelled future" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect(future.value_or_nil).to be_nil
    end

    it "stores cancellation error in _error" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect(future._error).to be_a(Smolagents::Executors::CancellationError)
    end
  end

  describe "value access after timeout" do
    it "marks future as cancelled after timeout" do
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        blocking_queue.pop # Never returns
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test", timeout: 0.01)
      future.execute!

      expect { future.value }.to raise_error(Smolagents::Executors::TimeoutError)
      expect(future.cancelled?).to be true
    end

    it "returns nil from value_or_nil after timeout" do
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        blocking_queue.pop
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test", timeout: 0.01)
      future.execute!

      # First access times out
      expect { future.value }.to raise_error(Smolagents::Executors::TimeoutError)

      # Subsequent access shows nil (future is now cancelled)
      expect(future.value_or_nil).to be_nil
    end
  end

  describe "duration tracking edge cases" do
    it "returns running duration when execution is still in progress" do
      started_queue = Thread::Queue.new
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        started_queue.push(:started)
        blocking_queue.pop
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      # Wait until agent is running
      started_queue.pop
      sleep 0.01 # Give it time to accumulate

      # Duration should be positive (still running)
      expect(future.duration).to be > 0
      expect(future._resolved?).to be false

      # Let it complete
      blocking_queue.push(:continue)
      future.value
    end

    it "freezes duration after completion" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.execute!
      future.value # Wait for completion

      duration1 = future.duration
      sleep 0.01
      duration2 = future.duration

      expect(duration1).to eq(duration2)
    end

    it "records duration even on error" do
      error_agent = instance_double(Smolagents::Agents::Agent)
      allow(error_agent).to receive(:run).and_raise(StandardError, "Boom")

      future = described_class.new(agent: error_agent, task: "Test")
      future.execute!
      future.value_or_nil # Wait without raising

      expect(future.duration).to be_a(Float)
      expect(future.duration).to be_positive
    end

    it "records duration on cancellation after execute" do
      started_queue = Thread::Queue.new
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        started_queue.push(:started)
        blocking_queue.pop # Wait to be cancelled
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      started_queue.pop # Wait for start
      future.cancel!

      expect(future.duration).to be_a(Float)
      expect(future.duration).to be >= 0
    end

    it "returns nil duration when cancelled before execute" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      # Started_at is nil when not executed, so duration is nil
      expect(future.duration).to be_nil
    end
  end

  describe "state transitions" do
    it "does not allow resolving after cancellation" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      # These should have no effect after cancellation
      future._resolve!("late result")

      expect(future.cancelled?).to be true
      expect(future.success?).to be false
    end

    it "inspect shows running state" do
      started_queue = Thread::Queue.new
      blocking_queue = Thread::Queue.new
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run) do
        started_queue.push(:started)
        blocking_queue.pop
        mock_result
      end

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      started_queue.pop # Wait until running
      expect(future.inspect).to include("running")

      blocking_queue.push(:continue)
      future.value
    end
  end

  describe "agent result handling" do
    it "extracts output from RunResult if available" do
      result_with_output = instance_double(Smolagents::Types::RunResult, output: "extracted")
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run).and_return(result_with_output)

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      expect(future.value).to eq("extracted")
    end

    it "returns raw result if no output method" do
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run).and_return("raw result")

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      expect(future.value).to eq("raw result")
    end

    it "handles nil output correctly" do
      result_with_nil = instance_double(Smolagents::Types::RunResult, output: nil)
      agent = instance_double(Smolagents::Agents::Agent)
      allow(agent).to receive(:run).and_return(result_with_nil)

      future = described_class.new(agent: agent, task: "Test")
      future.execute!

      expect(future.value).to be_nil
      expect(future.success?).to be true
    end
  end
end
