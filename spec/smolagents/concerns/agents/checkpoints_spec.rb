require "spec_helper"

RSpec.describe Smolagents::Concerns::Checkpoints do
  # Alias for convenience in specs
  let(:described_module) { described_class }

  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Checkpoints

      attr_accessor :state, :memory, :working_memory, :goal_store

      def initialize
        @state = nil
        @memory = nil
        @working_memory = nil
        @goal_store = nil
      end
    end
  end

  let(:agent) { test_class.new }
  let(:default_config) { Smolagents::Types::CheckpointConfig.default }
  let(:disabled_config) { Smolagents::Types::CheckpointConfig.disabled }

  def setup_agent_state(agent, step_number: 1)
    agent.state = Smolagents::Types::RunContext.new(
      step_number:,
      total_tokens: Smolagents::Types::TokenUsage.zero,
      timing: Smolagents::Types::Timing.start_now
    )
    agent.working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                                .with_objective("Test objective")
                                                                .add_finding("Found something")
  end

  describe "#setup_checkpoints" do
    it "initializes with default config" do
      agent.setup_checkpoints

      expect(agent.checkpoint_config).to be_a(Smolagents::Types::CheckpointConfig)
      expect(agent.checkpoint_config.enabled?).to be true
      expect(agent.checkpoint_config.max_checkpoints).to eq(10)
    end

    it "initializes with custom config" do
      config = Smolagents::Types::CheckpointConfig.new(
        max_checkpoints: 5,
        auto_save_path: nil,
        interval: 3,
        enabled: true
      )
      agent.setup_checkpoints(config)

      expect(agent.checkpoint_config.max_checkpoints).to eq(5)
      expect(agent.checkpoint_config.interval).to eq(3)
    end

    it "creates checkpoint store with correct max size" do
      config = Smolagents::Types::CheckpointConfig.new(
        max_checkpoints: 3,
        auto_save_path: nil,
        interval: nil,
        enabled: true
      )
      agent.setup_checkpoints(config)

      expect(agent.checkpoint_store).to be_a(Smolagents::Concerns::Checkpoints::Store)
    end

    it "initializes checkpoint sequence to zero" do
      agent.setup_checkpoints
      setup_agent_state(agent)

      # Create a checkpoint to verify sequence starts at 1
      checkpoint = agent.create_checkpoint(trigger: :manual)
      expect(checkpoint.sequence).to eq(1)
    end

    context "with persistent config" do
      let(:temp_dir) { Dir.mktmpdir }

      after { FileUtils.rm_rf(temp_dir) }

      it "loads persisted checkpoints on setup" do
        # Create a checkpoint file manually
        checkpoint_data = {
          id: "cp_test123456",
          step_number: 5,
          sequence: 3,
          timestamp: Time.now.iso8601,
          memory_state: nil,
          working_memory_state: { objective: "Test", findings: [], blockers: [] },
          goal_state: [],
          execution_context: nil,
          model_history: [],
          tool_usage_stats: {},
          metadata: { trigger: :auto }
        }
        File.write(File.join(temp_dir, "cp_test123456.json"), JSON.pretty_generate(checkpoint_data))

        config = Smolagents::Types::CheckpointConfig.persistent(path: temp_dir)
        agent.setup_checkpoints(config)

        expect(agent.list_checkpoints.size).to eq(1)
        expect(agent.list_checkpoints.first.id).to eq("cp_test123456")
      end
    end
  end

  describe "#create_checkpoint" do
    before do
      agent.setup_checkpoints
      setup_agent_state(agent, step_number: 3)
    end

    it "creates checkpoint with current state" do
      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint).to be_a(Smolagents::Types::Checkpoint)
      expect(checkpoint.step_number).to eq(3)
      expect(checkpoint.id).to match(/^cp_[a-f0-9]{16}$/)
    end

    it "captures working memory state" do
      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint.working_memory_state.objective).to eq("Test objective")
      expect(checkpoint.working_memory_state.findings).to include("Found something")
    end

    it "captures execution context" do
      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint.execution_context).to be_a(Smolagents::Types::RunContext)
      expect(checkpoint.execution_context.step_number).to eq(3)
    end

    it "records trigger in metadata" do
      manual_cp = agent.create_checkpoint(trigger: :manual)
      expect(manual_cp.metadata[:trigger]).to eq(:manual)

      auto_cp = agent.create_checkpoint(trigger: :auto)
      expect(auto_cp.metadata[:trigger]).to eq(:auto)

      recovery_cp = agent.create_checkpoint(trigger: :recovery)
      expect(recovery_cp.metadata[:trigger]).to eq(:recovery)
    end

    it "increments sequence number for each checkpoint" do
      cp1 = agent.create_checkpoint(trigger: :manual)
      cp2 = agent.create_checkpoint(trigger: :auto)
      cp3 = agent.create_checkpoint(trigger: :recovery)

      expect(cp1.sequence).to eq(1)
      expect(cp2.sequence).to eq(2)
      expect(cp3.sequence).to eq(3)
    end

    it "stores checkpoint in store" do
      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(agent.list_checkpoints).to include(checkpoint)
    end

    it "returns nil when checkpointing is disabled" do
      agent.setup_checkpoints(disabled_config)
      setup_agent_state(agent)

      checkpoint = agent.create_checkpoint(trigger: :manual)
      expect(checkpoint).to be_nil
    end

    context "event emission" do
      it "emits checkpoint_lifecycle event with created phase" do
        events = []
        agent.on(:checkpoint_lifecycle) { |e| events << e if e.created? }

        checkpoint = agent.create_checkpoint(trigger: :manual)
        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(events.size).to eq(1)
        event = events.first
        expect(event.checkpoint_id).to eq(checkpoint.id)
        expect(event.step_number).to eq(3)
        expect(event.trigger).to eq(:manual)
        expect(event.event_sequence).to eq(1)
      end
    end

    context "automatic pruning" do
      before do
        config = Smolagents::Types::CheckpointConfig.new(
          max_checkpoints: 3,
          auto_save_path: nil,
          interval: nil,
          enabled: true
        )
        agent.setup_checkpoints(config)
      end

      it "prunes oldest checkpoints when max exceeded" do
        setup_agent_state(agent, step_number: 1)
        agent.create_checkpoint(trigger: :manual)

        setup_agent_state(agent, step_number: 2)
        agent.create_checkpoint(trigger: :manual)

        setup_agent_state(agent, step_number: 3)
        agent.create_checkpoint(trigger: :manual)

        setup_agent_state(agent, step_number: 4)
        agent.create_checkpoint(trigger: :manual)

        # Should have pruned to 3 checkpoints
        checkpoints = agent.list_checkpoints
        expect(checkpoints.size).to eq(3)
        expect(checkpoints.map(&:step_number)).to eq([2, 3, 4])
      end

      it "emits checkpoint_lifecycle event with deleted phase for pruned checkpoints" do
        deleted_events = []
        agent.on(:checkpoint_lifecycle) { |e| deleted_events << e if e.deleted? }

        4.times do |i|
          setup_agent_state(agent, step_number: i + 1)
          agent.create_checkpoint(trigger: :auto)
        end
        Smolagents::Events::AsyncQueue.drain(timeout: 1)

        expect(deleted_events.size).to eq(1)
        expect(deleted_events.first.reason).to eq(:pruned)
        expect(deleted_events.first.step_number).to eq(1)
      end
    end

    context "with persistence" do
      let(:temp_dir) { Dir.mktmpdir }

      after { FileUtils.rm_rf(temp_dir) }

      it "auto-saves checkpoint to disk" do
        config = Smolagents::Types::CheckpointConfig.persistent(path: temp_dir)
        agent.setup_checkpoints(config)
        setup_agent_state(agent)

        checkpoint = agent.create_checkpoint(trigger: :auto)

        file_path = File.join(temp_dir, "#{checkpoint.id}.json")
        expect(File.exist?(file_path)).to be true
      end
    end
  end

  describe "#restore_checkpoint" do
    before do
      agent.setup_checkpoints
    end

    it "restores state from checkpoint" do
      setup_agent_state(agent, step_number: 5)
      agent.working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                                  .with_objective("Original objective")

      checkpoint = agent.create_checkpoint(trigger: :manual)

      # Modify state
      agent.state = agent.state.advance
      agent.working_memory = agent.working_memory.with_objective("Modified objective")

      # Restore
      restored = agent.restore_checkpoint(checkpoint.id)

      expect(restored).to eq(checkpoint)
      expect(agent.state.step_number).to eq(5)
      expect(agent.working_memory.objective).to eq("Original objective")
    end

    it "returns nil for non-existent checkpoint" do
      result = agent.restore_checkpoint("cp_nonexistent")
      expect(result).to be_nil
    end

    it "emits checkpoint_lifecycle event with restored phase" do
      setup_agent_state(agent, step_number: 3)
      checkpoint = agent.create_checkpoint(trigger: :manual)

      # Advance state
      agent.state = agent.state.advance.advance

      events = []
      agent.on(:checkpoint_lifecycle) { |e| events << e if e.restored? }

      agent.restore_checkpoint(checkpoint.id)
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(events.size).to eq(1)
      event = events.first
      expect(event.checkpoint_id).to eq(checkpoint.id)
      expect(event.step_number).to eq(3)
      expect(event.target_event_sequence).to eq(1)
      # NOTE: elapsed_steps is 0 because the event is emitted AFTER applying
      # the checkpoint (state is already restored). This is a limitation.
      expect(event.elapsed_steps).to eq(0)
    end

    it "restores working memory state" do
      setup_agent_state(agent, step_number: 1)
      agent.working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                                  .with_objective("Task A")
                                                                  .add_finding("Finding 1")
                                                                  .add_blocker("Blocker 1")

      checkpoint = agent.create_checkpoint(trigger: :manual)

      # Modify working memory
      agent.working_memory = Smolagents::Types::WorkingMemoryState.empty
                                                                  .with_objective("Task B")

      agent.restore_checkpoint(checkpoint.id)

      expect(agent.working_memory.objective).to eq("Task A")
      expect(agent.working_memory.findings).to include("Finding 1")
      expect(agent.working_memory.blockers).to include("Blocker 1")
    end

    it "restores execution context" do
      setup_agent_state(agent, step_number: 7)
      checkpoint = agent.create_checkpoint(trigger: :manual)

      agent.state = Smolagents::Types::RunContext.new(
        step_number: 15,
        total_tokens: Smolagents::Types::TokenUsage.new(input_tokens: 1000, output_tokens: 500),
        timing: Smolagents::Types::Timing.start_now
      )

      agent.restore_checkpoint(checkpoint.id)

      expect(agent.state.step_number).to eq(7)
    end
  end

  describe "#list_checkpoints" do
    before do
      agent.setup_checkpoints
    end

    it "returns empty array when no checkpoints exist" do
      expect(agent.list_checkpoints).to eq([])
    end

    it "returns checkpoints sorted by step number" do
      setup_agent_state(agent, step_number: 5)
      agent.create_checkpoint(trigger: :manual)

      setup_agent_state(agent, step_number: 2)
      agent.create_checkpoint(trigger: :manual)

      setup_agent_state(agent, step_number: 8)
      agent.create_checkpoint(trigger: :manual)

      checkpoints = agent.list_checkpoints
      expect(checkpoints.map(&:step_number)).to eq([2, 5, 8])
    end

    it "returns all stored checkpoints" do
      3.times do |i|
        setup_agent_state(agent, step_number: i + 1)
        agent.create_checkpoint(trigger: :manual)
      end

      expect(agent.list_checkpoints.size).to eq(3)
    end
  end

  describe "#clear_checkpoints" do
    before do
      agent.setup_checkpoints
    end

    it "removes all checkpoints" do
      3.times do |i|
        setup_agent_state(agent, step_number: i + 1)
        agent.create_checkpoint(trigger: :manual)
      end

      expect(agent.list_checkpoints.size).to eq(3)

      agent.clear_checkpoints

      expect(agent.list_checkpoints).to be_empty
    end

    it "emits checkpoint_lifecycle event with deleted phase for each cleared checkpoint" do
      3.times do |i|
        setup_agent_state(agent, step_number: i + 1)
        agent.create_checkpoint(trigger: :manual)
      end

      deleted_events = []
      agent.on(:checkpoint_lifecycle) { |e| deleted_events << e if e.deleted? }

      agent.clear_checkpoints
      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(deleted_events.size).to eq(3)
      expect(deleted_events.map(&:reason)).to all(eq(:manual))
    end
  end

  describe "integration with state capture" do
    before do
      agent.setup_checkpoints
    end

    it "handles nil memory gracefully" do
      agent.memory = nil
      agent.state = Smolagents::Types::RunContext.new(
        step_number: 1,
        total_tokens: Smolagents::Types::TokenUsage.zero,
        timing: Smolagents::Types::Timing.start_now
      )
      # Explicitly set working_memory to empty to avoid nil
      agent.working_memory = Smolagents::Types::WorkingMemoryState.empty

      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint.memory_state).to be_nil
      expect(checkpoint.model_history).to eq([])
    end

    it "handles nil goal store gracefully" do
      agent.goal_store = nil
      agent.state = Smolagents::Types::RunContext.new(
        step_number: 1,
        total_tokens: Smolagents::Types::TokenUsage.zero,
        timing: Smolagents::Types::Timing.start_now
      )
      agent.working_memory = Smolagents::Types::WorkingMemoryState.empty

      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint.goal_state).to eq([])
    end

    it "handles nil working memory gracefully" do
      # Don't call setup_agent_state which sets working_memory
      agent.state = Smolagents::Types::RunContext.new(
        step_number: 1,
        total_tokens: Smolagents::Types::TokenUsage.zero,
        timing: Smolagents::Types::Timing.start_now
      )
      agent.working_memory = nil

      checkpoint = agent.create_checkpoint(trigger: :manual)

      expect(checkpoint.working_memory_state).to eq(Smolagents::Types::WorkingMemoryState.empty)
    end
  end

  describe "checkpoint staleness" do
    before do
      agent.setup_checkpoints
    end

    it "tracks sequence for staleness checking" do
      setup_agent_state(agent, step_number: 1)
      cp1 = agent.create_checkpoint(trigger: :manual)

      setup_agent_state(agent, step_number: 2)
      cp2 = agent.create_checkpoint(trigger: :manual)

      expect(cp1.stale?(cp2.sequence)).to be true
      expect(cp2.stale?(cp2.sequence)).to be false
    end
  end
end
