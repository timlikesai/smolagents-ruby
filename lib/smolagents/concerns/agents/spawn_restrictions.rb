require_relative "spawn_validator"

module Smolagents
  module Concerns
    module Agents
      # Enforces spawn restrictions to prevent privilege escalation.
      #
      # SpawnRestrictions tracks spawn depth and enforces that child agents
      # have equal or lesser capabilities than their parent.
      #
      # == Enforcement
      #
      # - Spawn depth tracking (parent -> child -> grandchild)
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
      # @see SpawnValidator For validation logic
      module SpawnRestrictions
        include Events::Emitter
        include SpawnValidator

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
      end
    end
  end
end
