module Smolagents
  module Types
    # Valid scope levels in order of increasing context.
    CONTEXT_SCOPE_LEVELS = %i[task_only observations summary full].freeze

    # Defines how much context to pass to sub-agents.
    #
    # ContextScope controls the amount of parent context inherited by child agents
    # in multi-agent hierarchies. Different scopes provide different trade-offs
    # between context richness and token efficiency.
    #
    # == Scope Levels
    #
    # - +:task_only+ - Only the task description (minimal tokens)
    # - +:observations+ - Task plus parent observations (moderate)
    # - +:summary+ - Task plus summarized context (balanced)
    # - +:full+ - Complete parent memory (maximum context)
    #
    # @example Creating and using context scope
    #   scope = ContextScope.create(:observations)
    #   context = scope.extract_from(parent_memory, task: "Analyze data")
    #
    # @example Checking scope level
    #   scope.task_only?    # => false
    #   scope.observations? # => true
    #
    # @see Runtime::AgentMemory Memory structure for agents
    ContextScope = Data.define(:level) do
      # Creates a context scope with the given level.
      #
      # @param level [Symbol, String] Scope level (defaults to :task_only)
      # @return [ContextScope] New context scope
      # @raise [ArgumentError] If level is not valid
      #
      # @example Creating scopes
      #   scope = ContextScope.create              # => task_only
      #   scope = ContextScope.create(:summary)    # => summary
      def self.create(level = :task_only)
        level = level.to_sym
        unless CONTEXT_SCOPE_LEVELS.include?(level)
          raise ArgumentError, "Invalid scope: #{level}. Use: #{CONTEXT_SCOPE_LEVELS.join(", ")}"
        end

        new(level:)
      end

      # @!group Level Predicates

      # @return [Boolean] True if scope is task_only
      def task_only? = level == :task_only

      # @return [Boolean] True if scope is observations
      def observations? = level == :observations

      # @return [Boolean] True if scope is summary
      def summary? = level == :summary

      # @return [Boolean] True if scope is full
      def full? = level == :full

      # @!endgroup

      # Extracts context from memory according to scope level.
      #
      # @param memory [Runtime::AgentMemory] Parent agent's memory
      # @param task [String] Task description for sub-agent
      # @return [Hash] Context hash with appropriate content for scope level
      #
      # @example Extracting context
      #   context = scope.extract_from(memory, task: "Summarize findings")
      #   # => { task: "Summarize findings", parent_observations: "...", inherited_scope: :observations }
      def extract_from(memory, task:)
        case level
        when :task_only then { task:, inherited_scope: :task_only }
        when :observations then extract_observations(memory, task)
        when :summary then extract_summary(memory, task)
        when :full then extract_full(memory, task)
        end
      end

      private

      def extract_observations(memory, task)
        observations = memory.action_steps.to_a.filter_map(&:observations).join("\n---\n")
        { task:, parent_observations: observations, inherited_scope: :observations }
      end

      def extract_summary(memory, task)
        summary = memory.to_messages(summary_mode: true).map(&:content).join("\n")
        { task:, parent_summary: summary, inherited_scope: :summary }
      end

      def extract_full(memory, task)
        { task:, parent_memory: memory.to_messages, inherited_scope: :full }
      end
    end
  end
end
