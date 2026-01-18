module Smolagents
  module Concerns
    module Agents
      # Enforces spawn restrictions to prevent privilege escalation.
      #
      # SpawnRestrictions tracks spawn depth and enforces that child agents
      # have equal or lesser capabilities than their parent. This prevents
      # attacks where a sub-agent could gain access to unauthorized resources.
      #
      # == Enforcement
      #
      # - Spawn depth tracking (parent → child → grandchild)
      # - Tool subset restriction (child only gets tools parent has)
      # - Step budget enforcement (child steps <= parent remaining steps)
      # - Event emission when spawn is denied
      #
      # @example Including in an agent
      #   class MyAgent
      #     include SpawnRestrictions
      #
      #     def spawn_child(name:, tools:, steps:)
      #       validate_spawn!(requested_tools: tools, requested_steps: steps)
      #       # ... create child agent
      #     end
      #   end
      #
      # @see Security::SpawnPolicy For policy definition
      # @see Security::SpawnContext For context tracking
      module SpawnRestrictions
        include Events::Emitter

        def self.included(base)
          base.attr_reader :spawn_policy, :spawn_context
        end

        private

        # Initialize spawn restriction tracking.
        #
        # @param spawn_policy [Security::SpawnPolicy, nil] Policy to enforce
        # @param spawn_context [Security::SpawnContext, nil] Current context
        # @param max_steps [Integer] Max steps for root context
        # @param tools [Array<Symbol>] Available tools for root context
        # @return [void]
        def initialize_spawn_restrictions(spawn_policy: nil, spawn_context: nil, max_steps: 10, tools: [])
          @spawn_policy = spawn_policy || Security::SpawnPolicy.disabled
          @spawn_context = spawn_context || build_root_context(max_steps, tools)
        end

        # Validates a spawn request, raising if denied.
        #
        # @param requested_tools [Array<Symbol>] Tools for child
        # @param requested_steps [Integer, nil] Steps for child
        # @raise [Errors::SpawnError] If spawn is denied
        # @return [Security::SpawnValidation] Validation result if allowed
        def validate_spawn!(requested_tools: [], requested_steps: nil)
          return allow_spawn if spawn_policy_disabled?

          validation = perform_spawn_validation(requested_tools:, requested_steps:)
          handle_denied_spawn(validation) if validation.denied?
          validation
        end

        def spawn_policy_disabled? = @spawn_policy.nil? || @spawn_policy.disabled?

        def perform_spawn_validation(requested_tools:, requested_steps:)
          @spawn_policy.validate(@spawn_context, requested_tools:, requested_steps:)
        end

        def handle_denied_spawn(validation)
          emit_spawn_restricted(validation)
          raise Errors::SpawnError.new(validation.to_error_message, reason: validation.violations.first&.to_s)
        end

        # Checks if spawn is allowed without raising.
        #
        # @param requested_tools [Array<Symbol>] Tools for child
        # @param requested_steps [Integer, nil] Steps for child
        # @return [Boolean] True if spawn would be allowed
        def spawn_allowed?(requested_tools: [], requested_steps: nil)
          return true if spawn_policy_disabled?

          perform_spawn_validation(requested_tools:, requested_steps:).allowed?
        end

        # Creates a child context for a spawned agent.
        #
        # @param agent_name [String] Name of child agent
        # @param steps [Integer] Steps allocated to child
        # @param tools [Array<Symbol>] Tools for child
        # @return [Security::SpawnContext] Child context
        def child_spawn_context(agent_name:, steps:, tools: nil)
          effective_tools = tools || @spawn_context.parent_tools
          @spawn_context.descend(
            steps_allocated: steps,
            child_tools: effective_tools,
            agent_name:
          )
        end

        # Creates a child policy with inherited restrictions.
        #
        # @return [Security::SpawnPolicy] Restricted child policy
        def child_spawn_policy
          return @spawn_policy unless @spawn_policy&.inherit_restrictions

          @spawn_policy.child_policy(
            parent_tools: @spawn_context.parent_tools,
            remaining_steps: @spawn_context.remaining_steps
          )
        end

        # Returns the current spawn depth.
        #
        # @return [Integer] Current depth (0 = root)
        def spawn_depth = @spawn_context&.depth || 0

        # Returns the spawn path as a string.
        #
        # @return [String] Path like "root > researcher > checker"
        def spawn_path = @spawn_context&.path_string || "unknown"

        # Checks if this is the root agent.
        #
        # @return [Boolean] True if at root depth
        def root_agent? = spawn_depth.zero?

        # Returns remaining steps in the budget.
        #
        # @return [Integer] Remaining steps
        def remaining_spawn_budget = @spawn_context&.remaining_steps || 0

        # Updates remaining steps after using some.
        #
        # @param steps_used [Integer] Steps consumed
        # @return [void]
        def consume_spawn_budget(steps_used)
          return unless @spawn_context

          new_remaining = [@spawn_context.remaining_steps - steps_used, 0].max
          @spawn_context = @spawn_context.with(remaining_steps: new_remaining)
        end

        def build_root_context(max_steps, tools)
          tool_names = tools.respond_to?(:keys) ? tools.keys.map(&:to_sym) : tools.map(&:to_sym)
          Security::SpawnContext.root(max_steps:, tools: tool_names)
        end

        def emit_spawn_restricted(validation)
          return unless defined?(Events::SpawnRestricted)

          emit(Events::SpawnRestricted.create(
                 depth: @spawn_context.depth,
                 violations: validation.violations.map(&:to_s),
                 spawn_path: @spawn_context.path_string
               ))
        end

        def allow_spawn
          Security::SpawnValidation.new(allowed: true, violations: [].freeze)
        end
      end
    end
  end
end
