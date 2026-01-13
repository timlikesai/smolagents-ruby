module Smolagents
  module Types
    # PlanOutcome - the foundation of hierarchical planning and execution tracking.
    #
    # Outcomes represent both DESIRED (what we want) and ACTUAL (what happened) states.
    # They compose into trees for hierarchical decomposition of complex tasks.
    #
    # @example Simple desired outcome
    #   outcome = PlanOutcome.desired("Find 10 research papers",
    #     criteria: { count: 10, recency: 30.days }
    #   )
    #
    # @example Actual outcome from execution
    #   actual = PlanOutcome.actual("Find 10 research papers",
    #     state: :success,
    #     value: papers,
    #     duration: 2.5
    #   )
    #
    # @example Comparison
    #   actual.satisfies?(desired)  # => true/false
    #   actual.divergence(desired)  # => { count: { expected: 10, actual: 8 } }
    #
    PlanOutcome = Data.define(
      :kind,          # :desired, :actual, :expected (for testing)
      :description,   # Human-readable description
      :state,         # :pending, :success, :partial, :error (for actual)
      :value,         # The result value (for actual)
      :error,         # Error if failed (for actual)
      :duration,      # Execution time (for actual)
      :criteria,      # Success criteria (Hash or callable)
      :metadata,      # Additional context
      :parent,        # Parent outcome (for tree structure)
      :children       # Child outcomes (for decomposition)
    ) do
      # Initialize with defaults
      def initialize(
        kind: :desired,
        description: nil,
        state: :pending,
        value: nil,
        error: nil,
        duration: 0.0,
        criteria: {},
        metadata: {},
        parent: nil,
        children: []
      )
        super
      end

      # DSL: Create desired outcome
      # @example
      #   PlanOutcome.desired("Complete research", criteria: { min_sources: 10 })
      def self.desired(description, criteria: {}, **metadata)
        new(kind: :desired, description: description, criteria: criteria, metadata: metadata)
      end

      # DSL: Create actual outcome
      # @example
      #   PlanOutcome.actual("Complete research", state: :success, value: report, duration: 5.0)
      def self.actual(description, state:, value: nil, error: nil, duration: 0.0, **metadata)
        new(
          kind: :actual,
          description: description,
          state: state,
          value: value,
          error: error,
          duration: duration,
          metadata: metadata
        )
      end

      # DSL: Create expected outcome (for testing)
      # @example
      #   PlanOutcome.expected("API call", state: :success, value: { status: 200 })
      def self.expected(description, state:, value: nil, **metadata)
        new(kind: :expected, description: description, state: state, value: value, metadata: metadata)
      end

      # Predicates for outcome kind
      def desired? = kind == :desired
      def actual? = kind == :actual
      def expected? = kind == :expected

      # Predicates for state (actual outcomes)
      def pending? = state == :pending
      def success? = state == :success
      def partial? = state == :partial
      def error? = state == :error
      def completed? = success? || partial?
      def failed? = error?

      # Tree structure predicates
      def root? = parent.nil?
      def leaf? = children.empty?
      def has_children? = !children.empty?

      # Add child outcome (builds tree)
      # @example
      #   parent.add_child(PlanOutcome.desired("Sub-task"))
      def add_child(child_outcome)
        child_with_parent = child_outcome.with(parent: self)
        with(children: children + [child_with_parent])
      end

      # Validation: Check if actual outcome satisfies desired criteria
      # @example
      #   actual.satisfies?(desired)  # => true/false
      def satisfies?(desired_outcome)
        return false unless desired_outcome.desired?
        return true if desired_outcome.criteria.empty?

        # Evaluate each criterion
        desired_outcome.criteria.all? do |key, expected|
          actual_value = metadata[key] || value&.dig(key)
          evaluate_criterion(actual_value, expected)
        end
      end

      # Calculate divergence between actual and desired
      # @example
      #   actual.divergence(desired)
      #   # => { count: { expected: 10, actual: 8 }, quality: { expected: 0.8, actual: 0.9 } }
      def divergence(desired_outcome)
        return {} unless desired_outcome.desired?

        desired_outcome.criteria.each_with_object({}) do |(key, expected), divergences|
          actual_value = metadata[key] || value&.dig(key)

          divergences[key] = { expected: expected, actual: actual_value } unless evaluate_criterion(actual_value, expected)
        end
      end

      # Tree traversal: depth-first iteration
      # @example
      #   tree.each_descendant { |outcome| puts outcome.description }
      def each_descendant(&block)
        return enum_for(__method__) unless block

        yield(self)
        children.each { |child| child.each_descendant(&block) }
      end

      # Tree visualization
      # @example
      #   tree.trace
      #   # => "Research project"
      #   #    ├─ "Find sources" ✓
      #   #    └─ "Synthesize" ✗
      def trace(indent = 0, prefix = "")
        status = case state
                 when :success then "✓"
                 when :partial then "◐"
                 when :error then "✗"
                 when :pending then "○"
                 else " "
                 end

        line = "#{prefix}#{description} #{status}"
        line += " (#{duration.round(2)}s)" if duration&.positive?

        lines = [line]

        children.each_with_index do |child, idx|
          is_last = idx == children.length - 1
          child_prefix = "#{prefix}#{"  " * indent}#{is_last ? "└─ " : "├─ "}"
          lines += child.trace(indent + 1, child_prefix)
        end

        lines
      end

      # Convert to event payload for instrumentation
      def to_event_payload
        {
          kind: kind,
          description: description,
          state: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata
        }.tap do |payload|
          payload[:value] = value if value && actual?
          payload[:error] = error.class.name if error
          payload[:criteria] = criteria if criteria.any? && desired?
        end
      end

      private

      # Evaluate a single criterion
      def evaluate_criterion(actual_value, expected)
        case expected
        when Proc
          expected.call(actual_value)
        when Range
          expected.cover?(actual_value)
        when Regexp
          expected.match?(actual_value.to_s)
        when Hash
          # Nested hash comparison
          expected.all? { |k, v| evaluate_criterion(actual_value&.dig(k), v) }
        else
          actual_value == expected
        end
      end
    end
  end
end
