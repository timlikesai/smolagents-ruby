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
    module WorkingMemory
      # Maximum number of findings to retain.
      MAX_FINDINGS = 3

      # Maximum number of blockers to retain.
      MAX_BLOCKERS = 2

      # Initialize working memory state.
      def initialize_working_memory
        @working_memory = WorkingMemoryState.empty
      end

      # @return [WorkingMemoryState] current working memory
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
      def build_working_memory_context
        @working_memory.to_context
      end

      # Immutable working memory state.
      WorkingMemoryState = Data.define(:objective, :findings, :blockers) do
        class << self
          def empty
            new(objective: nil, findings: [], blockers: [])
          end
        end

        def with_objective(obj)
          with(objective: truncate(obj, 100))
        end

        def add_finding(finding)
          new_findings = [truncate(finding, 80), *findings].first(MAX_FINDINGS)
          with(findings: new_findings)
        end

        def add_blocker(blocker)
          new_blockers = [truncate(blocker, 60), *blockers].first(MAX_BLOCKERS)
          with(blockers: new_blockers)
        end

        def remove_blocker(blocker)
          with(blockers: blockers.reject { |b| b.include?(blocker) || blocker.include?(b) })
        end

        def clear_blockers
          with(blockers: [])
        end

        def to_context
          parts = []
          parts << "Objective: #{objective}" if objective
          parts << "Findings: #{findings.join("; ")}" if findings.any?
          parts << "Blockers: #{blockers.join("; ")}" if blockers.any?
          return nil if parts.empty?

          parts.join("\n")
        end

        def empty?
          objective.nil? && findings.empty? && blockers.empty?
        end

        private

        def truncate(text, max)
          return nil if text.nil?

          text.length > max ? "#{text[0, max - 3]}..." : text
        end
      end
    end
  end
end
