module Smolagents
  module Types
    # Snapshot of execution-specific state for checkpointing.
    #
    # Captures transient execution state: step history, pending observations,
    # tool results, error context, loop detection, and memory budget usage.
    #
    # @example Creating a snapshot
    #   snapshot = ExecutionStateSnapshot.capture(
    #     step_history: completed_steps,
    #     memory_budget_used: 4500
    #   )
    #
    # @see Checkpoint For full checkpoint type
    ExecutionStateSnapshot = Data.define(
      :step_history, :observations_buffer, :last_tool_result,
      :error_context, :loop_detection_state, :memory_budget_used
    ) do
      # @return [ExecutionStateSnapshot] Empty snapshot for initial state
      def self.empty
        new(step_history: [], observations_buffer: [], last_tool_result: nil,
            error_context: nil, loop_detection_state: {}, memory_budget_used: 0)
      end

      # Captures current execution state.
      # @return [ExecutionStateSnapshot]
      def self.capture(step_history:, observations_buffer: [], last_tool_result: nil,
                       error_context: nil, loop_detection_state: {}, memory_budget_used: 0)
        new(step_history:, observations_buffer:, last_tool_result:,
            error_context:, loop_detection_state:, memory_budget_used:)
      end

      # @return [Boolean] True if snapshot contains error state
      def error? = !error_context.nil?

      # @return [Boolean] True if observations buffer has pending items
      def pending_observations? = !observations_buffer.empty?

      # @return [Integer] Number of completed steps
      def step_count = step_history.size

      # @param total_budget [Integer] Total budget available
      # @return [Integer] Remaining tokens
      def budget_remaining(total_budget) = total_budget - memory_budget_used

      # @param total_budget [Integer] Total budget available
      # @return [Boolean] True if memory budget is exhausted
      def budget_exhausted?(total_budget) = memory_budget_used >= total_budget

      # @return [Hash] Serialized snapshot
      def to_h
        { step_history: step_history.map { |s| serialize_step(s) },
          observations_buffer:, last_tool_result:, error_context:,
          loop_detection_state:, memory_budget_used: }
      end

      # @param data [Hash] Serialized snapshot data
      # @return [ExecutionStateSnapshot]
      def self.from_h(data)
        new(step_history: data[:step_history] || [], observations_buffer: data[:observations_buffer] || [],
            last_tool_result: data[:last_tool_result], error_context: data[:error_context],
            loop_detection_state: data[:loop_detection_state] || {}, memory_budget_used: data[:memory_budget_used] || 0)
      end

      private

      def serialize_step(step)
        step.respond_to?(:to_h) ? step.to_h : step
      end
    end
  end
end
