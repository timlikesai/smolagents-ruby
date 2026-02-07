require "json"
require "fileutils"

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
      # Thread-safe checkpoint storage with automatic pruning.
      #
      # Stores checkpoints in memory with optional persistence.
      # Prunes old checkpoints when max capacity is reached.
      class Store
        def initialize(max_checkpoints:)
          @max_checkpoints = max_checkpoints
          @checkpoints = []
          @mutex = Mutex.new
        end

        # Add a checkpoint, pruning if over capacity.
        # @param checkpoint [Types::Checkpoint] Checkpoint to store
        # @yield [checkpoint] Block called for each pruned checkpoint
        # @return [Types::Checkpoint]
        def add(checkpoint, &)
          @mutex.synchronize do
            @checkpoints << checkpoint
            prune_if_needed(&)
          end
          checkpoint
        end

        # Find checkpoint by ID.
        # @param id [String] Checkpoint ID
        # @return [Types::Checkpoint, nil]
        def find(id)
          @mutex.synchronize { @checkpoints.find { |c| c.id == id } }
        end

        # Get all checkpoints sorted by step number.
        # @return [Array<Types::Checkpoint>]
        def all
          @mutex.synchronize { @checkpoints.sort_by(&:step_number) }
        end

        # Clear all checkpoints.
        # @yield [checkpoint] Block called for each cleared checkpoint
        # @return [void]
        def clear(&)
          @mutex.synchronize do
            @checkpoints.each(&) if block_given?
            @checkpoints.clear
          end
        end

        # Load checkpoints from an array (for persistence restore).
        # @param checkpoints [Array<Types::Checkpoint>]
        # @return [void]
        def load(checkpoints)
          @mutex.synchronize { @checkpoints.concat(checkpoints) }
        end

        # @return [Integer] Number of stored checkpoints
        def size
          @mutex.synchronize { @checkpoints.size }
        end

        private

        def prune_if_needed(&on_prune)
          return unless @checkpoints.size > @max_checkpoints

          @checkpoints.sort_by!(&:step_number)
          pruned = @checkpoints.shift(@checkpoints.size - @max_checkpoints)
          pruned.each(&on_prune) if on_prune
        end
      end

      # Serialize/deserialize checkpoints to JSON-safe formats.
      #
      # Handles nested types (ChatMessage, Goal, WorkingMemoryState) by
      # recursively converting to/from hash representations.
      module Serialization
        # Serialize a checkpoint to a JSON-compatible hash.
        # @param checkpoint [Types::Checkpoint] The checkpoint to serialize
        # @return [Hash] JSON-serializable hash
        def serialize_checkpoint(checkpoint) = checkpoint.to_h

        # Deserialize a checkpoint from a hash.
        # @param data [Hash] Serialized checkpoint data
        # @return [Types::Checkpoint] Reconstructed checkpoint
        def deserialize_checkpoint(data) = Types::Checkpoint.from_h(symbolize_keys(data))

        private

        def symbolize_keys(hash)
          return hash unless hash.is_a?(Hash)

          hash.each_with_object({}) do |(key, value), result|
            sym_key = key.is_a?(String) ? key.to_sym : key
            result[sym_key] = case value
                              when Hash then symbolize_keys(value)
                              when Array then value.map { |v| symbolize_keys(v) }
                              else value
                              end
          end
        end
      end

      # Persist checkpoints to disk for recovery across sessions.
      #
      # Saves checkpoints as JSON files in the configured directory.
      # Filenames use checkpoint ID for easy lookup.
      module Persistence
        include Serialization

        # Save a checkpoint to disk.
        # @param checkpoint [Types::Checkpoint] The checkpoint to save
        # @param path [String] Directory path for checkpoint files
        # @return [String] Full path to saved file
        def save_checkpoint(checkpoint, path)
          FileUtils.mkdir_p(path)
          file_path = checkpoint_file_path(checkpoint.id, path)
          File.write(file_path, JSON.pretty_generate(serialize_checkpoint(checkpoint)))
          file_path
        end

        # Load a checkpoint from disk.
        # @param file_path [String] Full path to checkpoint file
        # @return [Types::Checkpoint] Loaded checkpoint
        # @raise [Errno::ENOENT] If file doesn't exist
        def load_checkpoint(file_path)
          data = JSON.parse(File.read(file_path), symbolize_names: true)
          deserialize_checkpoint(data)
        end

        # Load all checkpoints from a directory.
        # @param path [String] Directory containing checkpoint files
        # @return [Array<Types::Checkpoint>] All checkpoints, sorted by step
        def load_all_checkpoints(path)
          return [] unless File.directory?(path)

          Dir.glob(File.join(path, "cp_*.json")).filter_map do |file|
            load_checkpoint(file)
          rescue JSON::ParserError, KeyError
            nil
          end.sort_by(&:step_number)
        end

        # Remove a checkpoint file from disk.
        # @param checkpoint_id [String] ID of checkpoint to remove
        # @param path [String] Directory containing checkpoint files
        # @return [Boolean] True if file was removed
        def checkpoint_file_removed?(checkpoint_id, path)
          file_path = checkpoint_file_path(checkpoint_id, path)
          return false unless File.exist?(file_path)

          File.delete(file_path)
          true
        end

        private

        def checkpoint_file_path(checkpoint_id, path)
          File.join(path, "#{checkpoint_id}.json")
        end
      end

      # State capture and restore methods for checkpoints.
      #
      # Override these methods in your agent to customize what state
      # is captured in checkpoints and how it is restored.
      module StateCapture
        private

        # @return [Integer] Current step number for checkpoint
        def current_step_number = @state&.step_number || 0

        # @return [Hash] Serialized memory state
        def capture_memory_state = @memory&.to_h

        # @return [Types::WorkingMemoryState] Current working memory
        def capture_working_memory_state = @working_memory || Types::WorkingMemoryState.empty

        # @return [Array<Types::Goal>] All goals
        def capture_goal_state = @goal_store&.all || []

        # @return [Types::RunContext, nil] Current execution context
        def capture_execution_context = @state

        # @return [Array<Types::ChatMessage>] Model conversation history
        def capture_model_history = @memory&.messages&.dup || []

        # Restore memory state from checkpoint.
        # @param _state [Hash] Serialized memory state
        # @return [void]
        def restore_memory_state(_state) = nil

        # Restore working memory from checkpoint.
        # @param state [Types::WorkingMemoryState] Working memory state
        # @return [void]
        def restore_working_memory_state(state)
          @working_memory = state if state
        end

        # Restore goals from checkpoint.
        # @param _goals [Array<Types::Goal>] Goals to restore
        # @return [void]
        def restore_goal_state(_goals) = nil

        # Restore execution context from checkpoint.
        # @param ctx [Types::RunContext] Execution context
        # @return [void]
        def restore_execution_context(ctx)
          @state = ctx if ctx
        end
      end

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
        emit :checkpoint_lifecycle, phase: :created, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number,
                                    trigger:, event_sequence: checkpoint.sequence
      end

      def emit_checkpoint_restored(checkpoint)
        emit :checkpoint_lifecycle, phase: :restored, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number,
                                    target_event_sequence: checkpoint.sequence,
                                    elapsed_steps: current_step_number - checkpoint.step_number
      end

      def emit_checkpoint_deleted(checkpoint, reason)
        emit :checkpoint_lifecycle, phase: :deleted, checkpoint_id: checkpoint.id, step_number: checkpoint.step_number,
                                    reason:
      end
    end
  end
end
