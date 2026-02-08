module Smolagents
  module Concerns
    # Working memory for essential state that survives context truncation.
    #
    # Maintains a compact representation of critical information:
    # - Current goal/objective
    # - Key blockers or obstacles
    # - Important findings from tool calls
    #
    # This is Layer 1 (PERSISTENT) - always included in context assembly.
    # Budget is ~100 tokens to stay compact.
    #
    # @example Basic usage
    #   class MyAgent
    #     include Concerns::WorkingMemory
    #
    #     def initialize
    #       initialize_working_memory
    #     end
    #   end
    #
    # @see Context::Layer::PERSISTENT For the persistent layer
    # @see GoalTracking For goal management
    # @see Types::WorkingMemoryState For the immutable state type
    module WorkingMemory
      # Initialize working memory state.
      def initialize_working_memory
        @working_memory = Types::WorkingMemoryState.empty
      end

      # @return [Types::WorkingMemoryState] current working memory
      attr_reader :working_memory

      # Update objective from current goal or task.
      # @param objective [String] what we're trying to accomplish
      def update_objective(objective)
        @working_memory = @working_memory.with_objective(objective)
      end

      # Record a key finding from tool output.
      # @param finding [String] important information discovered
      def record_finding(finding)
        return if finding.nil? || finding.empty?

        @working_memory = @working_memory.add_finding(finding)
      end

      # Record a blocker or obstacle.
      # @param blocker [String] what's blocking progress
      def record_blocker(blocker)
        return if blocker.nil? || blocker.empty?

        @working_memory = @working_memory.add_blocker(blocker)
      end

      # Clear a blocker when resolved.
      # @param blocker [String] blocker to remove
      def clear_blocker(blocker)
        @working_memory = @working_memory.remove_blocker(blocker)
      end

      # Clear all blockers.
      def clear_all_blockers
        @working_memory = @working_memory.clear_blockers
      end

      # Build context contribution for the LLM.
      # @return [String, nil] formatted working memory context
      def build_working_memory_context = @working_memory.to_context

      # Estimated token usage of working memory content.
      # Uses 4 chars per token heuristic.
      # @return [Integer] estimated tokens used
      def memory_token_estimate
        text = build_working_memory_context
        return 0 if text.nil?

        (text.length / 4.0).ceil
      end

      # Summary of working memory state.
      # @return [String]
      def memory_summary
        wm = @working_memory
        parts = []
        parts << "objective: #{wm.objective ? "set" : "none"}"
        parts << "#{wm.findings.size} findings" if wm.findings.any?
        parts << "#{wm.blockers.size} blockers" if wm.blockers.any?
        parts << "empty" if wm.empty?
        "Working memory: #{parts.join(", ")}"
      end
    end
  end
end
