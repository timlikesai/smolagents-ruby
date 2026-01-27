require_relative "checkpoints/serialization"
require_relative "checkpoints/persistence"
require_relative "checkpoints/store"
require_relative "checkpoints/state_capture"

module Smolagents
  module Concerns
    # Checkpoint management for agent execution state.
    #
    # Enables saving and restoring agent state at specific points,
    # supporting time-travel debugging and recovery from failures.
    #
    # @example Basic usage
    #   class MyAgent
    #     include Concerns::Checkpoints
    #
    #     def initialize
    #       setup_checkpoints
    #     end
    #   end
    #
    # @see Types::Checkpoint For checkpoint data structure
    # @see Types::CheckpointConfig For configuration options
    module Checkpoints
      include Events::Emitter
      include Persistence
      include StateCapture

      def self.included(base)
        base.attr_reader :checkpoint_store, :checkpoint_config
      end

      # Initialize checkpoint storage with configuration.
      # @param config [Types::CheckpointConfig] Checkpoint configuration
      # @return [void]
      def setup_checkpoints(config = Types::CheckpointConfig.default)
        @checkpoint_config = config
        @checkpoint_store = Store.new(max_checkpoints: config.max_checkpoints)
        @checkpoint_sequence = 0
        load_persisted_checkpoints if config.persistent?
      end

      # Create a checkpoint at current state.
      # @param trigger [Symbol] What triggered the checkpoint (:manual, :auto, :recovery)
      # @return [Types::Checkpoint, nil] Created checkpoint or nil if disabled
      def create_checkpoint(trigger: :manual)
        return nil unless @checkpoint_config&.enabled?

        checkpoint = capture_state(trigger)
        @checkpoint_store.add(checkpoint) { |cp| emit_checkpoint_deleted(cp, :pruned) }
        auto_save_checkpoint(checkpoint) if @checkpoint_config.persistent?
        emit_checkpoint_created(checkpoint, trigger)
        checkpoint
      end

      # Restore agent state from a checkpoint.
      # @param checkpoint_id [String] ID of checkpoint to restore
      # @return [Types::Checkpoint, nil] Restored checkpoint or nil if not found
      def restore_checkpoint(checkpoint_id)
        checkpoint = @checkpoint_store.find(checkpoint_id)
        return nil unless checkpoint

        apply_checkpoint(checkpoint)
        emit_checkpoint_restored(checkpoint)
        checkpoint
      end

      # List all available checkpoints.
      # @return [Array<Types::Checkpoint>] Checkpoints sorted by step number
      def list_checkpoints = @checkpoint_store.all

      # Clear all checkpoints.
      # @return [void]
      def clear_checkpoints = @checkpoint_store.clear { |cp| emit_checkpoint_deleted(cp, :manual) }

      private

      def capture_state(trigger)
        @checkpoint_sequence += 1
        Types::Checkpoint.capture(
          step_number: current_step_number, sequence: @checkpoint_sequence,
          memory_state: capture_memory_state, working_memory_state: capture_working_memory_state,
          goal_state: capture_goal_state, execution_context: capture_execution_context,
          model_history: capture_model_history, metadata: { trigger: }
        )
      end

      def apply_checkpoint(checkpoint)
        restore_memory_state(checkpoint.memory_state)
        restore_working_memory_state(checkpoint.working_memory_state)
        restore_goal_state(checkpoint.goal_state)
        restore_execution_context(checkpoint.execution_context)
      end

      def load_persisted_checkpoints
        return unless @checkpoint_config.auto_save_path

        @checkpoint_store.load(load_all_checkpoints(@checkpoint_config.auto_save_path))
      end

      def auto_save_checkpoint(checkpoint)
        save_checkpoint(checkpoint, @checkpoint_config.auto_save_path) if @checkpoint_config.auto_save_path
      end

      def emit_checkpoint_created(checkpoint, trigger)
        emit :checkpoint_created, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number,
                                  trigger:, event_sequence: checkpoint.sequence
      end

      def emit_checkpoint_restored(checkpoint)
        emit :checkpoint_restored, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number,
                                   target_event_sequence: checkpoint.sequence,
                                   elapsed_steps: current_step_number - checkpoint.step_number
      end

      def emit_checkpoint_deleted(checkpoint, reason)
        emit :checkpoint_deleted, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number, reason:
      end
    end
  end
end
