module Smolagents
  module Concerns
    # Accumulates runtime statistics from agent events.
    #
    # Subscribes to lifecycle events and maintains an immutable {Types::AgentStats}
    # snapshot, updated thread-safely via Mutex.
    #
    # @example Including in an agent
    #   class MyAgent
    #     include Events::Consumer
    #     include Concerns::StatsTracking
    #
    #     def initialize
    #       initialize_stats
    #     end
    #   end
    #
    # @example Reading stats
    #   agent.stats.steps_taken      # => 3
    #   agent.stats.total_tokens     # => 450
    #   agent.stats.tool_error_rate  # => 0.1
    #
    # @see Types::AgentStats For the immutable stats type
    module StatsTracking
      def self.included(base)
        base.include(Events::Consumer)
      end

      # Returns current agent statistics snapshot.
      #
      # @return [Types::AgentStats]
      def stats
        @stats_mutex.synchronize { @stats }
      end

      private

      def initialize_stats
        @stats = Types::AgentStats.zero
        @stats_mutex = Mutex.new
        subscribe_stats_events
      end

      def subscribe_stats_events
        on(:step_completed) { |event| record_stats_step(event) }
        on(:tool_call_completed) { |event| record_stats_tool(event) }
        on(:model_generation) { |event| record_stats_model(event) }
        on(:error_occurred) { |event| record_stats_error(event) }
      end

      def record_stats_step(_event)
        @stats_mutex.synchronize { @stats = @stats.record_step }
      end

      def record_stats_tool(_event)
        @stats_mutex.synchronize { @stats = @stats.record_tool_call }
      end

      def record_stats_model(event)
        return unless event.completed?

        @stats_mutex.synchronize do
          @stats = @stats.record_model_call(**extract_model_kwargs(event))
        end
      end

      def extract_model_kwargs(event)
        usage = event.token_usage || {}
        prompt = usage[:input_tokens] || 0
        completion = usage[:output_tokens] || 0
        { tokens: prompt + completion, prompt:, completion:, duration_ms: event.duration_ms || 0 }
      end

      def record_stats_error(_event)
        @stats_mutex.synchronize { @stats = @stats.record_error }
      end
    end
  end
end
