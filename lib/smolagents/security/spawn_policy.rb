require_relative "spawn_context"
require_relative "spawn_violation"
require_relative "spawn_validation"

module Smolagents
  module Security
    # Policy controlling sub-agent spawning with privilege restriction.
    #
    # SpawnPolicy enforces that child agents have equal or lesser capabilities
    # than their parent. This prevents privilege escalation attacks where a
    # sub-agent could gain access to tools or resources its parent lacks.
    #
    # == Restrictions
    #
    # - +max_depth+ - Maximum nesting depth (parent -> child -> grandchild)
    # - +allowed_tools+ - Tools available to spawned agents (subset of parent)
    # - +max_steps_per_agent+ - Step budget for each spawned agent
    # - +inherit_restrictions+ - Whether children inherit parent restrictions
    #
    # @example Creating a spawn policy
    #   policy = SpawnPolicy.create(
    #     max_depth: 2,
    #     allowed_tools: [:search, :final_answer],
    #     max_steps_per_agent: 5
    #   )
    #
    # @example Checking if spawn is allowed
    #   context = SpawnContext.create(depth: 1, remaining_steps: 10, parent_tools: [:search])
    #   result = policy.validate(context, requested_tools: [:search])
    #   result.allowed?  #=> true
    #
    # @see Types::SpawnConfig For basic spawn configuration
    # @see Concerns::SpawnRestrictions For enforcement in agents
    SpawnPolicy = Data.define(:max_depth, :allowed_tools, :max_steps_per_agent, :inherit_restrictions) do
      def self.create(max_depth: 2, allowed_tools: [:final_answer], max_steps_per_agent: 10, inherit_restrictions: true)
        new(max_depth:, allowed_tools: Array(allowed_tools).map(&:to_sym).freeze, max_steps_per_agent:,
            inherit_restrictions:)
      end

      def self.disabled
        new(max_depth: 0, allowed_tools: [].freeze, max_steps_per_agent: 0, inherit_restrictions: true)
      end

      def self.permissive(tools: nil)
        new(max_depth: 10, allowed_tools: tools&.map(&:to_sym)&.freeze || :any, max_steps_per_agent: 100,
            inherit_restrictions: false)
      end

      def validate(context, requested_tools: [], requested_steps: nil)
        violations = []
        violations << depth_violation(context) if depth_exceeded?(context)
        violations.concat(tool_violations(context, requested_tools))
        violations << steps_violation(context, requested_steps) if steps_exceeded?(context, requested_steps)
        SpawnValidation.new(allowed: violations.empty?, violations: violations.freeze)
      end

      def child_policy(parent_tools:, remaining_steps:)
        return self unless inherit_restrictions

        child_tools = compute_child_tools(parent_tools)
        child_steps = [max_steps_per_agent, remaining_steps].min
        with(allowed_tools: child_tools.freeze, max_steps_per_agent: child_steps)
      end

      def enabled? = max_depth.positive?
      def disabled? = max_depth.zero?
      def any_tool_allowed? = allowed_tools == :any

      private

      def depth_exceeded?(context) = context.depth >= max_depth

      def steps_exceeded?(context, requested_steps)
        return false unless requested_steps

        requested_steps > context.remaining_steps || requested_steps > max_steps_per_agent
      end

      def tool_violations(context, requested_tools)
        return [] if any_tool_allowed?

        (requested_tools.map(&:to_sym) - effective_allowed_tools(context))
          .map { |tool| SpawnViolation.unauthorized_tool(tool) }
      end

      def effective_allowed_tools(context)
        any_tool_allowed? ? allowed_tools : allowed_tools & context.parent_tools
      end

      def compute_child_tools(parent_tools)
        any_tool_allowed? ? parent_tools : allowed_tools & parent_tools.map(&:to_sym)
      end

      def depth_violation(context)
        SpawnViolation.depth_exceeded(current: context.depth, max: max_depth)
      end

      def steps_violation(context, requested_steps)
        SpawnViolation.steps_exceeded(
          requested: requested_steps,
          max_per_agent: max_steps_per_agent,
          remaining: context.remaining_steps
        )
      end
    end
  end
end
