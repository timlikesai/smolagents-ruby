module Smolagents
  module Concerns
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
    end
  end
end
