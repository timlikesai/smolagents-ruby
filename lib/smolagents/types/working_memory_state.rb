module Smolagents
  module Types
    # Immutable working memory state for agent runtime.
    #
    # Maintains a compact representation of critical information that
    # survives context truncation:
    # - Current goal/objective
    # - Key blockers or obstacles
    # - Important findings from tool calls
    #
    # Budget is ~100 tokens to stay compact.
    #
    # @example Creating empty state
    #   state = WorkingMemoryState.empty
    #   state.empty?  # => true
    #
    # @example Building up state
    #   state = WorkingMemoryState.empty
    #     .with_objective("Find Ruby 4.0 release notes")
    #     .add_finding("Found official blog post")
    #     .add_blocker("Rate limited by API")
    #
    # @see Concerns::WorkingMemory For the concern that uses this type
    WorkingMemoryState = Data.define(:objective, :findings, :blockers) do
      # Maximum number of findings to retain.
      MAX_FINDINGS = 3

      # Maximum number of blockers to retain.
      MAX_BLOCKERS = 2

      class << self
        # Create an empty working memory state.
        # @return [WorkingMemoryState]
        def empty = new(objective: nil, findings: [], blockers: [])
      end

      # Update the objective.
      # @param obj [String] New objective
      # @return [WorkingMemoryState]
      def with_objective(obj) = with(objective: truncate(obj, 100))

      # Add a finding to the state.
      # @param finding [String] Finding to add
      # @return [WorkingMemoryState]
      def add_finding(finding)
        new_findings = [truncate(finding, 80), *findings].first(MAX_FINDINGS)
        with(findings: new_findings)
      end

      # Add a blocker to the state.
      # @param blocker [String] Blocker to add
      # @return [WorkingMemoryState]
      def add_blocker(blocker)
        new_blockers = [truncate(blocker, 60), *blockers].first(MAX_BLOCKERS)
        with(blockers: new_blockers)
      end

      # Remove a blocker from the state.
      # @param blocker [String] Blocker to remove (partial match)
      # @return [WorkingMemoryState]
      def remove_blocker(blocker)
        with(blockers: blockers.reject { |b| b.include?(blocker) || blocker.include?(b) })
      end

      # Clear all blockers.
      # @return [WorkingMemoryState]
      def clear_blockers = with(blockers: [])

      # Format as context string for LLM.
      # @return [String, nil] Formatted context or nil if empty
      def to_context
        parts = []
        parts << "Objective: #{objective}" if objective
        parts << "Findings: #{findings.join("; ")}" if findings.any?
        parts << "Blockers: #{blockers.join("; ")}" if blockers.any?
        return nil if parts.empty?

        parts.join("\n")
      end

      # Check if state is empty.
      # @return [Boolean]
      def empty? = objective.nil? && findings.empty? && blockers.empty?

      private

      def truncate(text, max)
        return nil if text.nil?

        text.length > max ? "#{text[0, max - 3]}..." : text
      end
    end
  end
end
