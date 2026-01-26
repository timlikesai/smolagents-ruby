module Smolagents
  module Concerns
    module Agents
      # Spawn validation logic for enforcing privilege restrictions.
      #
      # Handles the validation of spawn requests, including policy checks
      # and context creation for child agents.
      #
      # @see SpawnRestrictions For the main spawn restriction concern
      module SpawnValidator
        private

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

        def allow_spawn
          Security::SpawnValidation.new(allowed: true, violations: [].freeze)
        end

        def emit_spawn_restricted(validation)
          return unless defined?(Events::SpawnRestricted)

          emit(Events::SpawnRestricted.create(
                 depth: @spawn_context.depth,
                 violations: validation.violations.map(&:to_s),
                 spawn_path: @spawn_context.path_string
               ))
        end
      end
    end
  end
end
