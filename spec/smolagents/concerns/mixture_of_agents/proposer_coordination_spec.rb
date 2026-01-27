# rubocop:disable RSpec/MessageSpies, RSpec/StubbedMock, Smolagents/NoSleep
require "spec_helper"

RSpec.describe Smolagents::Concerns::MixtureOfAgents::ProposerCoordination do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::MixtureOfAgents::ProposerCoordination
    end
  end

  let(:coordinator) { test_class.new }

  let(:mock_run_result) do
    Smolagents::Types::RunResult.success(
      output: "Test result",
      steps: [
        Smolagents::Types::ActionStep.new(
          step_number: 1,
          observations: "Found the answer"
        )
      ]
    )
  end

  let(:mock_agent) do
    agent = instance_double(Smolagents::Agents::Agent)
    allow(agent).to receive(:run).and_return(mock_run_result)
    agent
  end

  let(:mock_config) do
    Smolagents::Types::MoAConfig.create(
      proposer_count: 3,
      aggregation_strategy: :voting,
      timeout_per_proposer: 30
    )
  end

  # Helper to create mock future that returns the given result
  def stub_agent_future_with(result)
    mock_future = instance_double(Smolagents::Executors::AgentFuture)
    allow(mock_future).to receive_messages(execute!: mock_future, value: result)
    allow(Smolagents::Executors::AgentFuture).to receive(:new).and_return(mock_future)
    mock_future
  end

  # Helper to create a mock future for specific test cases
  def create_mock_future_returning(result)
    mock_future = instance_double(Smolagents::Executors::AgentFuture)
    allow(mock_future).to receive_messages(execute!: mock_future, value: result)
    mock_future
  end

  describe "#run_proposers_parallel" do
    let(:proposers) { [mock_agent, mock_agent, mock_agent] }

    before do
      stub_agent_future_with(mock_run_result)
    end

    it "returns proposals from all proposers" do
      proposals = coordinator.run_proposers_parallel("Test task", proposers, mock_config)

      expect(proposals.size).to eq(3)
      proposals.each do |proposal|
        expect(proposal).to be_a(Smolagents::Types::Proposal)
      end
    end

    it "converts RunResult to Proposal" do
      proposals = coordinator.run_proposers_parallel("Test task", proposers, mock_config)

      proposals.each do |proposal|
        expect(proposal.result).to eq("Test result")
        expect(proposal.task).to eq("Test task")
      end
    end

    it "assigns proposer names based on index" do
      proposals = coordinator.run_proposers_parallel("Test task", proposers, mock_config)

      expect(proposals.map(&:proposer_name)).to eq(%w[proposer_0 proposer_1 proposer_2])
    end

    it "emits proposer_launched event for each proposer" do
      # Verify emit is called with correct parameters
      expect(coordinator).to receive(:emit).with(
        :proposer_launched,
        hash_including(proposer_name: "proposer_0", proposer_index: 0, task: "Test task", total_proposers: 3)
      ).ordered
      expect(coordinator).to receive(:emit).with(
        :proposer_launched,
        hash_including(proposer_name: "proposer_1", proposer_index: 1)
      ).ordered
      expect(coordinator).to receive(:emit).with(
        :proposer_launched,
        hash_including(proposer_name: "proposer_2", proposer_index: 2)
      ).ordered

      # Also allow proposal_received emissions
      allow(coordinator).to receive(:emit).with(:proposal_received, anything)

      coordinator.run_proposers_parallel("Test task", proposers, mock_config)
    end

    it "emits proposal_received event for each completed proposal" do
      # Allow proposer_launched emissions
      allow(coordinator).to receive(:emit).with(:proposer_launched, anything)

      # Verify proposal_received is called 3 times
      expect(coordinator).to receive(:emit).with(
        :proposal_received,
        hash_including(:proposer_name, :confidence, :duration_ms, :result_preview)
      ).exactly(3).times

      coordinator.run_proposers_parallel("Test task", proposers, mock_config)
    end

    context "with timeouts" do
      let(:slow_agent) do
        agent = instance_double(Smolagents::Agents::Agent)
        allow(agent).to receive(:run) do
          sleep 0.5
          mock_run_result
        end
        agent
      end

      # Use minimum valid proposer count (2)
      let(:timeout_config) do
        Smolagents::Types::MoAConfig.create(
          proposer_count: 2,
          aggregation_strategy: :voting,
          timeout_per_proposer: 0.05
        )
      end

      it "handles timeouts gracefully by returning nil for timed out proposers" do
        # Mock AgentFuture to simulate timeout
        mock_future = instance_double(Smolagents::Executors::AgentFuture)
        allow(mock_future).to receive(:execute!).and_return(mock_future)
        allow(mock_future).to receive(:value).and_raise(
          Smolagents::Executors::TimeoutError, "Timed out"
        )

        allow(Smolagents::Executors::AgentFuture).to receive(:new).and_return(mock_future)
        allow(coordinator).to receive(:emit) # Allow all emissions

        # Run with 2 proposers (minimum), both will timeout
        proposals = coordinator.run_proposers_parallel("Test task", [slow_agent, slow_agent], timeout_config)

        # Timed out proposers return nil and are compacted out
        expect(proposals).to be_empty
      end

      it "emits error event on timeout" do
        mock_future = instance_double(Smolagents::Executors::AgentFuture)
        allow(mock_future).to receive(:execute!).and_return(mock_future)
        allow(mock_future).to receive(:value).and_raise(
          Smolagents::Executors::TimeoutError, "Timed out"
        )
        allow(Smolagents::Executors::AgentFuture).to receive(:new).and_return(mock_future)

        # Allow proposer_launched emissions
        allow(coordinator).to receive(:emit).with(:proposer_launched, anything)

        # Expect emit_error to be called for each timed out proposer
        expect(coordinator).to receive(:emit_error).with(
          kind_of(Smolagents::Executors::TimeoutError),
          context: hash_including(proposer_index: kind_of(Integer)),
          recoverable: true
        ).twice

        coordinator.run_proposers_parallel("Test task", [slow_agent, slow_agent], timeout_config)
      end
    end

    context "with cancellation" do
      it "handles cancellation errors gracefully" do
        mock_future = instance_double(Smolagents::Executors::AgentFuture)
        allow(mock_future).to receive(:execute!).and_return(mock_future)
        allow(mock_future).to receive(:value).and_raise(
          Smolagents::Executors::CancellationError, "Cancelled"
        )
        allow(Smolagents::Executors::AgentFuture).to receive(:new).and_return(mock_future)

        proposals = coordinator.run_proposers_parallel("Test task", [mock_agent], mock_config)

        expect(proposals).to be_empty
      end
    end
  end

  describe "AgentFuture creation" do
    it "creates futures with correct parameters" do
      mock_future = create_mock_future_returning(mock_run_result)

      expect(Smolagents::Executors::AgentFuture).to receive(:new).with(
        agent: mock_agent,
        task: "Test task",
        timeout: 30
      ).and_return(mock_future)

      coordinator.run_proposers_parallel("Test task", [mock_agent], mock_config)
    end

    it "calls execute! on each future" do
      mock_future = create_mock_future_returning(mock_run_result)
      allow(Smolagents::Executors::AgentFuture).to receive(:new).and_return(mock_future)

      expect(mock_future).to receive(:execute!).exactly(3).times.and_return(mock_future)

      coordinator.run_proposers_parallel("Test task", [mock_agent] * 3, mock_config)
    end
  end

  describe "Proposal construction" do
    before do
      stub_agent_future_with(mock_run_result)
    end

    it "extracts confidence from RunResult" do
      successful_result = Smolagents::Types::RunResult.success(
        output: "Success",
        steps: []
      )
      stub_agent_future_with(successful_result)

      proposals = coordinator.run_proposers_parallel("Test task", [mock_agent], mock_config)

      # Successful results get default confidence of 0.7
      expect(proposals.first.confidence).to eq(0.7)
    end

    it "extracts reasoning from action steps" do
      result_with_steps = Smolagents::Types::RunResult.success(
        output: "Result",
        steps: [
          Smolagents::Types::ActionStep.new(step_number: 1, observations: "Step 1 obs"),
          Smolagents::Types::ActionStep.new(step_number: 2, observations: "Step 2 obs")
        ]
      )
      stub_agent_future_with(result_with_steps)

      proposals = coordinator.run_proposers_parallel("Test task", [mock_agent], mock_config)

      expect(proposals.first.reasoning).to include("Step 1 obs")
      expect(proposals.first.reasoning).to include("Step 2 obs")
    end

    it "calculates duration from RunResult timing" do
      timed_result = Smolagents::Types::RunResult.success(
        output: "Result",
        steps: [],
        timing: Smolagents::Types::Timing.new(
          start_time: Time.now - 2,
          end_time: Time.now
        )
      )
      stub_agent_future_with(timed_result)

      proposals = coordinator.run_proposers_parallel("Test task", [mock_agent], mock_config)

      expect(proposals.first.duration_ms).to be_within(100).of(2000)
    end
  end

  describe "Events::Emitter integration" do
    it "includes Events::Emitter automatically" do
      expect(test_class.ancestors).to include(Smolagents::Events::Emitter)
    end

    it "does not duplicate Emitter if already included" do
      class_with_emitter = Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Concerns::MixtureOfAgents::ProposerCoordination
      end

      # Should not raise, and should include Emitter only once
      expect(class_with_emitter.ancestors.count(Smolagents::Events::Emitter)).to eq(1)
    end
  end
end

# rubocop:enable RSpec/MessageSpies, RSpec/StubbedMock, Smolagents/NoSleep
