module Smolagents
  module Types
    # Maps agent run states to goal states
    GOAL_STATE_MAP = { success: :success, error: :error, max_steps_reached: :partial }.freeze

    # Goal - Unified task/goal type with fluent DSL, composition, and criteria.
    #
    # Goals represent desired outcomes that can be bound to agents and executed.
    # They support rich criteria matching, composition operators, and templates.
    #
    # @example Basic goal with criteria
    #   goal = Goal.desired("Find research papers")
    #     .expect_count(10..20)
    #     .expect_quality(0.8)
    #
    # @example Agent binding and execution
    #   result = Goal.desired("Analyze data")
    #     .with_agent(analyzer)
    #     .run!
    #
    # @example Composition
    #   both = goal_a & goal_b    # AND - all must succeed
    #   any = goal_a | goal_b     # OR - first success wins
    #
    # @example Templates
    #   template = Goal.template("Research :topic")
    #   goal = template.for(topic: "AI Safety")
    #
    Goal = Data.define(
      :kind, :desc, :state, :value, :error,
      :duration, :criteria, :metadata, :agent, :deps, :parts, :mode
    ) do
      def initialize(
        kind: :desired, desc: nil, state: :pending, value: nil, error: nil,
        duration: 0.0, criteria: {}, metadata: {}, agent: nil, deps: [], parts: [], mode: nil
      )
        super
      end

      # === Factories ===

      def self.desired(desc, **meta) = new(kind: :desired, desc: desc, metadata: meta)
      def self.actual(desc, state:, **) = new(kind: :actual, desc: desc, state: state, **)
      def self.template(pattern) = new(kind: :template, desc: pattern)
      def self.result(desc, state:, **) = new(kind: :result, desc: desc, state: state, **)

      def self.from_agent_result(result, desired: nil)
        actual(
          desired&.desc || "Agent execution",
          state: GOAL_STATE_MAP[result.state] || :pending,
          value: result.output,
          duration: result.timing&.duration || 0.0,
          metadata: { steps: result.steps&.size || 0, tokens: result.token_usage&.total_tokens || 0 }
        )
      end

      # === Criteria DSL ===

      def expect(key, value = nil, &block)
        with(criteria: criteria.merge(key => block || value))
      end

      def expect_quality(min_score)
        expect(:quality, min_score.is_a?(Range) ? min_score : min_score..1.0)
      end

      def expect_count(range_or_min, max = nil)
        expect(:count, build_range(range_or_min, max))
      end

      def expect_recent(days:) = expect(:recency_days, 1..days)
      def expect_format(fmt) = expect(:format, fmt.to_s)
      def expect_length(range_or_min, max = nil) = expect(:length, build_range(range_or_min, max))
      def expect_fast(seconds:) = expect(:max_duration, 0..seconds)
      def expect_sources(range_or_min, max = nil) = expect(:sources, build_range(range_or_min, max))

      # === Agent Binding ===

      def with_agent(bound_agent) = with(agent: bound_agent)

      def with(bound_agent = nil, **kw)
        kw[:agent] = bound_agent if bound_agent && !bound_agent.is_a?(Hash)
        super(**kw)
      end

      def run!
        raise ArgumentError, "No agent bound" unless agent

        composite? ? run_composite! : run_single!
      end

      # === Dependencies ===

      def after(*outcomes) = with(deps: deps + outcomes.flatten)

      def ready?(completed)
        deps.all? { |d| completed.any? { |c| c.desc == d.desc && c.success? } }
      end

      # === Templates ===

      def for(**vars)
        raise ArgumentError, "Not a template" unless template?

        filled = vars.reduce(desc) { |s, (k, v)| s.gsub(":#{k}", v.to_s) }
        with(kind: :desired, desc: filled)
      end

      # === Composition ===

      def &(other)
        composite? && mode == :all ? with(parts: parts + [other]) : Goal.new(mode: :all, parts: [self, other])
      end

      def |(other)
        composite? && mode == :any ? with(parts: parts + [other]) : Goal.new(mode: :any, parts: [self, other])
      end

      def composite? = parts.any?

      # === Predicates ===

      def desired? = kind == :desired
      def actual? = kind == :actual
      def result? = kind == :result
      def template? = kind == :template
      def pending? = state == :pending
      def success? = state == :success
      def partial? = state == :partial
      def error? = state == :error
      def failed? = error?
      def done? = !pending?
      def bound? = !agent.nil?

      # === Satisfaction ===

      def satisfies?(desired_goal)
        return false unless desired_goal.desired? && (success? || partial?)
        return true if desired_goal.criteria.empty?

        desired_goal.criteria.all? { |k, e| check_criterion(value_for(k), e) }
      end

      def >=(other) = satisfies?(other)

      def divergence(desired_goal)
        desired_goal.criteria.reject { |k, e| check_criterion(value_for(k), e) }
      end

      # === Display ===

      def status_icon
        { success: "✓", partial: "◐", error: "✗", pending: "○" }[state] || "?"
      end

      def to_s
        icon = template? ? "📋" : status_icon
        line = "#{desc} #{icon}"
        line += " (#{duration.round(2)}s)" if duration.positive?
        line += " [#{criteria.size} criteria]" if criteria.any?
        line
      end

      def inspect = "#<Goal:#{kind} #{desc.inspect} state=#{state}>"

      private

      def build_range(range_or_min, max)
        case range_or_min
        when Range then range_or_min
        when Numeric then max ? range_or_min..max : range_or_min..Float::INFINITY
        end
      end

      def value_for(key)
        metadata[key] || value&.dig(key) || value
      end

      def check_criterion(actual, expected)
        case expected
        when Proc then expected.call(actual)
        when Range then expected.cover?(actual)
        when Regexp then expected.match?(actual.to_s)
        when Hash then expected.all? { |k, v| check_criterion(actual&.dig(k), v) }
        else actual == expected
        end
      end

      def run_single!
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        r = agent.run(desc)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
        Goal.result(desc, state: GOAL_STATE_MAP[r.state] || :pending, value: r.output, duration: elapsed)
      rescue StandardError => e
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
        Goal.result(desc, state: :error, error: e, duration: elapsed)
      end

      def run_composite!
        results = []
        parts.each do |p|
          results << p.with_agent(agent).run!
          break if mode == :any && results.last.success?
        end
        ok = mode == :all ? results.all?(&:success?) : results.any?(&:success?)
        Goal.result("(#{mode})", state: ok ? :success : :error, value: results, duration: results.sum(&:duration))
      end
    end
  end
end

require_relative "goal_dynamic"
