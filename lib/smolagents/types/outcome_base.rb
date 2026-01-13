module Smolagents
  module Types
    # PlanOutcome - Simple value object for tracking desired vs actual outcomes.
    #
    # Outcomes represent both DESIRED (what we want) and ACTUAL (what happened).
    # Keep them flat - use agent orchestration (TeamBuilder) for hierarchy.
    #
    # @example Desired outcome
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
    # @example List of outcomes (for parallel work)
    #   outcomes = [
    #     PlanOutcome.desired("Research topic A"),
    #     PlanOutcome.desired("Research topic B"),
    #     PlanOutcome.desired("Research topic C")
    #   ]
    #
    #   # Orchestrate with TeamBuilder
    #   team = Smolagents.team
    #     .agent(researcher_a, as: "a")
    #     .agent(researcher_b, as: "b")
    #     .agent(researcher_c, as: "c")
    #     .build
    #
    PlanOutcome = Data.define(
      :kind,          # :desired, :actual, :expected (for testing)
      :description,   # Human-readable description
      :state,         # :pending, :success, :partial, :error (for actual)
      :value,         # The result value (for actual)
      :error,         # Error if failed (for actual)
      :duration,      # Execution time in seconds (for actual)
      :criteria,      # Success criteria (Hash with values, ranges, or procs)
      :metadata       # Additional context
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
        metadata: {}
      )
        super
      end

      # ============================================================
      # Factory Methods (DSL)
      # ============================================================

      # Create desired outcome (what we want)
      def self.desired(description, criteria: {}, **metadata)
        new(kind: :desired, description: description, criteria: criteria, metadata: metadata)
      end

      # Create actual outcome (what happened)
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

      # Create expected outcome (for testing assertions)
      def self.expected(description, state:, value: nil, **metadata)
        new(kind: :expected, description: description, state: state, value: value, metadata: metadata)
      end

      # Create outcome from agent result
      def self.from_agent_result(result, desired: nil)
        actual(
          desired&.description || "Agent execution",
          state: map_result_state(result.state),
          value: result.output,
          duration: result.timing&.duration || 0.0,
          metadata: {
            steps_taken: result.steps&.size || 0,
            tokens: result.token_usage&.total_tokens || 0
          }
        )
      end

      # ============================================================
      # Predicates
      # ============================================================

      def desired? = kind == :desired
      def actual? = kind == :actual
      def expected? = kind == :expected

      def pending? = state == :pending
      def success? = state == :success
      def partial? = state == :partial
      def error? = state == :error
      def completed? = success? || partial?
      def failed? = error?

      # ============================================================
      # Validation & Comparison
      # ============================================================

      # Check if actual outcome satisfies desired criteria
      def satisfies?(desired_outcome)
        return false unless desired_outcome.desired?
        return true if desired_outcome.criteria.empty?

        desired_outcome.criteria.all? do |key, expected|
          actual_value = metadata[key] || value&.dig(key)
          evaluate_criterion(actual_value, expected)
        end
      end

      # Calculate divergence between actual and desired
      def divergence(desired_outcome)
        return {} unless desired_outcome.desired?

        desired_outcome.criteria.each_with_object({}) do |(key, expected), divergences|
          actual_value = metadata[key] || value&.dig(key)
          divergences[key] = { expected: expected, actual: actual_value } unless evaluate_criterion(actual_value, expected)
        end
      end

      # ============================================================
      # Display
      # ============================================================

      # Status indicator for display
      def status_icon
        case state
        when :success then "✓"
        when :partial then "◐"
        when :error then "✗"
        when :pending then "○"
        else " "
        end
      end

      # One-line summary
      def to_s
        line = "#{description} #{status_icon}"
        line += " (#{duration.round(2)}s)" if duration&.positive?
        line
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

      def evaluate_criterion(actual_value, expected)
        case expected
        when Proc then expected.call(actual_value)
        when Range then expected.cover?(actual_value)
        when Regexp then expected.match?(actual_value.to_s)
        when Hash then expected.all? { |k, v| evaluate_criterion(actual_value&.dig(k), v) }
        else actual_value == expected
        end
      end

      def self.map_result_state(result_state)
        case result_state
        when :success then :success
        when :max_steps_reached then :partial
        when :error then :error
        else :pending
        end
      end
    end
  end
end
