module Smolagents
  module Types
    # Execution checkpoint for agent state capture and rollback.
    #
    # @example checkpoint = Checkpoint.capture(step_number: 5, sequence: 42, ...)
    # @see CheckpointConfig For checkpoint configuration
    Checkpoint = Data.define(
      :id, :step_number, :sequence, :memory_state, :working_memory_state,
      :goal_state, :execution_context, :model_history, :tool_usage_stats,
      :timestamp, :metadata
    ) do
      # @return [Checkpoint] New checkpoint with generated ID and timestamp
      def self.capture(step_number:, sequence:, memory_state:, working_memory_state:,
                       goal_state:, execution_context:, model_history:,
                       tool_usage_stats: {}, metadata: {})
        new(id: "cp_#{SecureRandom.hex(8)}", step_number:, sequence:, memory_state:,
            working_memory_state:, goal_state:, execution_context:, model_history:,
            tool_usage_stats:, timestamp: Time.now, metadata:)
      end

      # @return [Float] Age of checkpoint in seconds
      def age = Time.now - timestamp

      # @return [Boolean] True if checkpoint is stale
      def stale?(current_sequence) = sequence < current_sequence

      # @return [Hash] Serialized checkpoint for persistence
      def to_h
        { id:, step_number:, sequence:, timestamp: timestamp.iso8601,
          memory_state:, tool_usage_stats:, metadata:,
          working_memory_state: serialize_working_memory,
          goal_state: goal_state.map(&:to_h),
          execution_context: serialize_execution_context,
          model_history: model_history.map(&:to_h) }
      end

      # @return [Checkpoint] Deserialized checkpoint
      def self.from_h(data)
        new(**deserialize_core(data), **deserialize_nested(data), **deserialize_optional(data))
      end

      def self.deserialize_core(data)
        { id: data[:id], step_number: data[:step_number], sequence: data[:sequence],
          timestamp: Time.parse(data[:timestamp]), memory_state: data[:memory_state] }
      end

      def self.deserialize_nested(data)
        { working_memory_state: deserialize_working_memory(data[:working_memory_state]),
          goal_state: data[:goal_state].map { |g| Goal.from_data(**g.transform_keys(&:to_sym)) },
          execution_context: deserialize_execution_context(data[:execution_context]),
          model_history: data[:model_history].map { |m| deserialize_message(m) } }
      end

      def self.deserialize_optional(data)
        { tool_usage_stats: data[:tool_usage_stats] || {}, metadata: data[:metadata] || {} }
      end

      def self.deserialize_working_memory(data)
        data.nil? ? WorkingMemoryState.empty : WorkingMemoryState.new(**data.transform_keys(&:to_sym))
      end

      def self.deserialize_execution_context(data)
        return nil if data.nil?

        d = data.transform_keys(&:to_sym)
        RunContext.new(step_number: d[:step_number], total_tokens: deserialize_tokens(d[:total_tokens]),
                       timing: deserialize_timing(d[:timing]))
      end

      def self.deserialize_timing(data)
        return Timing.start_now if data.nil?
        return data if data.is_a?(Timing)

        end_raw = data[:end_time] || data["end_time"]
        Timing.new(start_time: Time.parse(data[:start_time] || data["start_time"]),
                   end_time: end_raw ? Time.parse(end_raw) : nil)
      end

      def self.deserialize_tokens(data)
        return TokenUsage.zero if data.nil?
        return data if data.is_a?(TokenUsage)

        TokenUsage.new(input_tokens: data[:input_tokens] || data["input_tokens"] || 0,
                       output_tokens: data[:output_tokens] || data["output_tokens"] || 0)
      end

      private

      def serialize_working_memory
        return nil if working_memory_state.nil?

        { objective: working_memory_state.objective, findings: working_memory_state.findings,
          blockers: working_memory_state.blockers }
      end

      def serialize_execution_context
        execution_context&.to_h
      end
    end
  end
end
