module Smolagents
  module Tools
    class ManagedAgentTool < Tool
      # Spawn policy enforcement for managed agent execution.
      #
      # Validates spawn requests against the parent's spawn policy before
      # allowing sub-agent execution. Prevents privilege escalation.
      #
      # @see Security::SpawnPolicy For policy definition
      # @see Security::SpawnContext For context tracking
      module SpawnEnforcement
        attr_accessor :spawn_policy, :spawn_context

        # Validates spawn policy before executing the managed agent.
        #
        # @param task [String] The task to execute
        # @raise [Errors::SpawnError] If spawn policy denies execution
        # @return [Object] Result from agent execution
        def execute_with_policy_check(task:)
          validate_spawn_policy!
          execute_without_policy_check(task:)
        end

        private

        # Validates that spawning this agent is allowed by policy.
        #
        # @raise [Errors::SpawnError] If policy denies spawn
        # @return [Security::SpawnValidation] Validation result if allowed
        def validate_spawn_policy!
          return unless policy_enforcement_enabled?

          validation = perform_policy_validation
          raise_spawn_error(validation) if validation.denied?
        end

        def policy_enforcement_enabled? = @spawn_policy && @spawn_context

        def perform_policy_validation
          @spawn_policy.validate(@spawn_context, requested_tools: agent_tool_names, requested_steps: @agent.max_steps)
        end

        def agent_tool_names = @agent.tools.keys.map(&:to_sym)

        def raise_spawn_error(validation)
          emit_spawn_restricted(validation)
          raise Errors::SpawnError.new(validation.to_error_message, agent_name: @agent_name,
                                                                    reason: validation.violations.first&.to_s)
        end

        def emit_spawn_restricted(validation)
          return unless respond_to?(:emit_event)

          emit_event(Events::SpawnRestricted.create(
                       agent_name: @agent_name,
                       depth: @spawn_context.depth,
                       violations: validation.violations.map(&:to_s),
                       spawn_path: @spawn_context.path_string
                     ))
        end

        # Creates child spawn context for nested spawning.
        #
        # @return [Security::SpawnContext] Context for child agents
        def child_spawn_context
          return nil unless @spawn_context

          @spawn_context.descend(
            steps_allocated: @agent.max_steps,
            child_tools: @agent.tools.keys.map(&:to_sym),
            agent_name: @agent_name
          )
        end

        # Creates child spawn policy with inherited restrictions.
        #
        # @return [Security::SpawnPolicy] Policy for child agents
        def child_spawn_policy
          return @spawn_policy unless @spawn_policy&.inherit_restrictions

          @spawn_policy.child_policy(
            parent_tools: @spawn_context.parent_tools,
            remaining_steps: @spawn_context.remaining_steps
          )
        end

        # Propagates spawn restrictions to the managed agent.
        #
        # @return [void]
        def propagate_spawn_restrictions
          return unless @agent.respond_to?(:spawn_policy=) && @spawn_policy

          @agent.spawn_policy = child_spawn_policy
          @agent.spawn_context = child_spawn_context if @agent.respond_to?(:spawn_context=)
        end
      end
    end
  end
end
