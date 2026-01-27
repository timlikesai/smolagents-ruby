module Smolagents
  module Concerns
    module Checkpoints
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
    end
  end
end
