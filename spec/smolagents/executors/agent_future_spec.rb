require "spec_helper"

RSpec.describe Smolagents::Executors::AgentFuture do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:mock_result) { instance_double(Smolagents::Types::RunResult, output: "test result") }

  let(:mock_agent) do
    agent = instance_double(Smolagents::Agents::Agent)
    allow(agent).to receive(:run).and_return(mock_result)
    agent
  end

  describe "#initialize" do
    it "creates a pending future" do
      future = described_class.new(agent: mock_agent, task: "Test task")

      expect(future._pending?).to be true
      expect(future._resolved?).to be false
    end

    it "stores agent and task" do
      future = described_class.new(agent: mock_agent, task: "Test task")

      expect(future.agent).to eq(mock_agent)
      expect(future.task).to eq("Test task")
    end

    it "freezes context" do
      future = described_class.new(agent: mock_agent, task: "Test", context: { parent: 1 })

      expect(future.context).to be_frozen
    end
  end

  describe "#execute!" do
    it "starts execution in background" do
      future = described_class.new(agent: mock_agent, task: "Test task")
      future.execute!

      # Use value to block until completion (event-driven)
      future.value
      expect(future._resolved?).to be true
    end

    it "returns self for chaining" do
      future = described_class.new(agent: mock_agent, task: "Test task")

      expect(future.execute!).to eq(future)
    end

    it "is idempotent" do
      future = described_class.new(agent: mock_agent, task: "Test task")
      future.execute!
      future.value # Wait for completion
      future.execute!

      expect(mock_agent).to have_received(:run).once
    end
  end

  describe "#value" do
    it "returns agent output after completion" do
      future = described_class.new(agent: mock_agent, task: "Test task")
      future.execute!

      expect(future.value).to eq("test result")
    end

    it "blocks until completion" do
      # Use a Queue to coordinate - mock agent signals when done
      done_queue = Thread::Queue.new
      slow_agent = instance_double(Smolagents::Agents::Agent)
      allow(slow_agent).to receive(:run) do
        done_queue.push(:done)
        mock_result
      end

      future = described_class.new(agent: slow_agent, task: "Test")
      future.execute!

      # Block until agent signals it's about to return
      done_queue.pop
      expect(future.value).to eq("test result")
    end

    it "raises on error" do
      error_agent = instance_double(Smolagents::Agents::Agent)
      allow(error_agent).to receive(:run).and_raise(StandardError, "Agent failed")

      future = described_class.new(agent: error_agent, task: "Test")
      future.execute!

      expect { future.value }.to raise_error(StandardError, "Agent failed")
    end
  end

  describe "#value_or_nil" do
    it "returns result on success" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.execute!

      expect(future.value_or_nil).to eq("test result")
    end

    it "returns nil on error" do
      error_agent = instance_double(Smolagents::Agents::Agent)
      allow(error_agent).to receive(:run).and_raise(StandardError, "Failed")

      future = described_class.new(agent: error_agent, task: "Test")
      future.execute!

      expect(future.value_or_nil).to be_nil
    end
  end

  describe "#cancel!" do
    it "cancels pending execution" do
      future = described_class.new(agent: mock_agent, task: "Test")

      expect(future.cancel!).to be true
      expect(future.cancelled?).to be true
    end

    it "returns false if already resolved" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.execute!
      future.value # Wait for completion

      expect(future.cancel!).to be false
    end

    it "marks future as resolved" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect(future._resolved?).to be true
      expect(future.failed?).to be true
    end
  end

  describe "#success?" do
    it "returns true on successful completion" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.execute!
      future.value # Wait for completion

      expect(future.success?).to be true
    end

    it "returns false on failure" do
      error_agent = instance_double(Smolagents::Agents::Agent)
      allow(error_agent).to receive(:run).and_raise(StandardError)

      future = described_class.new(agent: error_agent, task: "Test")
      future.execute!
      future.value_or_nil # Wait for completion without raising

      expect(future.success?).to be false
    end

    it "returns false when cancelled" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect(future.success?).to be false
    end
  end

  describe "#duration" do
    it "returns nil before execution" do
      future = described_class.new(agent: mock_agent, task: "Test")

      expect(future.duration).to be_nil
    end

    it "returns elapsed time after completion" do
      started_queue = Thread::Queue.new
      slow_agent = instance_double(Smolagents::Agents::Agent)
      allow(slow_agent).to receive(:run) do
        started_queue.push(:started)
        mock_result
      end

      future = described_class.new(agent: slow_agent, task: "Test")
      future.execute!

      started_queue.pop # Wait until agent starts
      future.value # Wait for completion

      # Duration should be a positive number (Float)
      expect(future.duration).to be_a(Float)
      expect(future.duration).to be_positive
    end
  end

  describe "#inspect" do
    it "shows pending state" do
      future = described_class.new(agent: mock_agent, task: "Test task")

      expect(future.inspect).to include("pending")
      expect(future.inspect).to include("Test task")
    end

    it "shows resolved state" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.execute!
      future.value # Wait for completion

      expect(future.inspect).to include("resolved")
    end

    it "shows cancelled state" do
      future = described_class.new(agent: mock_agent, task: "Test")
      future.cancel!

      expect(future.inspect).to include("cancelled")
    end
  end

  describe "timeout handling" do
    it "cancels and raises on timeout" do
      # Use a Queue to block the agent until we're ready
      block_queue = Thread::Queue.new
      slow_agent = instance_double(Smolagents::Agents::Agent)
      allow(slow_agent).to receive(:run) do
        block_queue.pop # Wait for signal that will never come
        mock_result
      end

      future = described_class.new(agent: slow_agent, task: "Test", timeout: 0.05)
      future.execute!

      expect { future.value }.to raise_error(Smolagents::Executors::TimeoutError)
    end
  end

  describe "FutureBase protocol" do
    it "implements _future?" do
      future = described_class.new(agent: mock_agent, task: "Test")

      expect(future._future?).to be true
    end

    it "implements _resolved?" do
      future = described_class.new(agent: mock_agent, task: "Test")

      expect(future._resolved?).to be false
      future.cancel!
      expect(future._resolved?).to be true
    end

    it "implements _pending?" do
      future = described_class.new(agent: mock_agent, task: "Test")

      expect(future._pending?).to be true
      future.cancel!
      expect(future._pending?).to be false
    end
  end
end
