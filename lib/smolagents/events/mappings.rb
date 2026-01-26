module Smolagents
  module Events
    # Maps convenience symbol names to event classes.
    #
    # Provides resolution between user-friendly symbol names (e.g., :step_complete)
    # and event classes (e.g., StepCompleted). Used internally by {Consumer}
    # and {Emitter} to support both registration styles.
    #
    # This allows agents to accept event handlers using either form:
    #   agent.on(:step_complete) { |e| ... }        # Convenience name
    #   agent.on(StepCompleted) { |e| ... }         # Direct class
    #
    # @example Resolving names to classes
    #   Mappings.resolve(:step_complete)  # => StepCompleted
    #   Mappings.resolve(StepCompleted)   # => StepCompleted (pass-through)
    #
    # @example Checking valid names
    #   Mappings.valid?(:step_complete)   # => true
    #   Mappings.valid?(:unknown)         # => false
    #   Mappings.valid?(StepCompleted)    # => true
    #
    # @see Consumer For event handler registration
    # @see Emitter For event emission
    #
    module Mappings
      # Maps convenience symbol names to event class factories.
      #
      # Uses Procs/lambdas to avoid circular dependencies when the Events
      # module is being loaded. Each entry maps a symbol name to a lambda
      # that returns the corresponding event class.
      #
      # Supported event names:
      # - Tool operations: :tool_call, :tool_complete
      # - Step/task lifecycle: :step_complete, :task_complete
      # - Sub-agents: :agent_launch, :agent_progress, :agent_complete
      # - Error handling: :error, :rate_limit
      # - Reliability: :retry, :failover, :recovery, :tool_retrying
      #
      # @return [Hash{Symbol => Proc}] Name to event class factory mappings
      EVENTS = {
        # Tool events
        tool_call: -> { ToolCallRequested },
        tool_complete: -> { ToolCallCompleted },
        tool_isolation_started: -> { ToolIsolationStarted },
        tool_isolation_completed: -> { ToolIsolationCompleted },
        resource_violation: -> { ResourceViolation },

        # Lifecycle events
        step_complete: -> { StepCompleted },
        task_complete: -> { TaskCompleted },
        configuration_changed: -> { ConfigurationChanged },

        # Sub-agent events
        agent_launch: -> { SubAgentLaunched },
        agent_progress: -> { SubAgentProgress },
        agent_complete: -> { SubAgentCompleted },
        spawn_restricted: -> { SpawnRestricted },

        # Error events
        error: -> { ErrorOccurred },
        rate_limit: -> { RateLimitHit },
        rate_limit_violated: -> { RateLimitViolated },

        # Model events
        model_generate_requested: -> { ModelGenerateRequested },
        model_generate_completed: -> { ModelGenerateCompleted },
        tool_call_parsed: -> { ToolCallParsed },

        # Resilience events
        retry: -> { RetryRequested },
        failover: -> { FailoverOccurred },
        recovery: -> { RecoveryCompleted },
        health_check_requested: -> { HealthCheckRequested },
        health_check_completed: -> { HealthCheckCompleted },
        model_discovered: -> { ModelDiscovered },
        model_changed: -> { ModelChanged },
        circuit_state_changed: -> { CircuitStateChanged },
        queue_request_started: -> { QueueRequestStarted },
        queue_request_completed: -> { QueueRequestCompleted },
        request_failed: -> { RequestFailed },
        request_retried: -> { RequestRetried },
        tool_retrying: -> { ToolRetrying },

        # Control flow events
        control_yielded: -> { ControlYielded },
        control_resumed: -> { ControlResumed },

        # Metacognition events
        evaluation_complete: -> { EvaluationCompleted },
        refinement_complete: -> { RefinementCompleted },
        mixed_refinement_complete: -> { MixedRefinementCompleted },
        reflection_recorded: -> { ReflectionRecorded },
        goal_drift: -> { GoalDriftDetected },
        completion_rejected: -> { CompletionRejected },
        plan_divergence: -> { PlanDivergence },
        repetition_detected: -> { RepetitionDetected },

        # Goal tracking events
        goal_created: -> { GoalCreated },
        goal_progress: -> { GoalProgress },
        goal_completed: -> { GoalCompleted },

        # Orchestration events (EDAA Phase 1)
        work_item_queued: -> { WorkItemQueued },
        work_item_dispatched: -> { WorkItemDispatched },
        work_item_completed: -> { WorkItemCompleted },
        agent_step_requested: -> { AgentStepRequested },
        code_execution_requested: -> { CodeExecutionRequested },
        code_execution_completed: -> { CodeExecutionCompleted },
        sub_agent_requested: -> { SubAgentRequested }
      }.freeze

      class << self
        # Resolves a name or class to an event class.
        #
        # If passed a class, returns it as-is. If passed a symbol name,
        # looks it up in {EVENTS} and returns the corresponding class.
        #
        # @param name_or_class [Symbol, Class] Event name or class
        # @return [Class] The resolved event class
        # @raise [ArgumentError] If name is unknown
        #
        # @example
        #   resolve(:step_complete)      # => StepCompleted
        #   resolve(StepCompleted)       # => StepCompleted
        #   resolve(:unknown)            # => ArgumentError
        #
        # @see #valid? To check names without resolving
        def resolve(name_or_class)
          return name_or_class if name_or_class.is_a?(Class)

          factory = EVENTS[name_or_class]
          raise ArgumentError, "Unknown event: #{name_or_class}. Valid: #{EVENTS.keys.join(", ")}" unless factory

          factory.call
        end

        # Checks if a name or class is a valid event identifier.
        #
        # Returns true for both symbol names and event classes.
        # Useful for validating configuration before resolving.
        #
        # @param name_or_class [Symbol, Class] Name or class to check
        # @return [Boolean] True if valid, false otherwise
        #
        # @example
        #   valid?(:step_complete)   # => true
        #   valid?(:unknown)         # => false
        #   valid?(StepCompleted)    # => true
        #
        # @see #resolve For converting to event classes
        def valid?(name_or_class)
          return true if name_or_class.is_a?(Class)

          EVENTS.key?(name_or_class)
        end

        # Returns all valid event name symbols.
        #
        # @return [Array<Symbol>] All supported event names
        #
        # @example
        #   Mappings.names  # => [:tool_call, :tool_complete, :step_complete, ...]
        def names = EVENTS.keys

        # Returns all event classes.
        #
        # @return [Array<Class>] All event classes
        #
        # @example
        #   Mappings.classes  # => [ToolCallRequested, ToolCallCompleted, ...]
        def classes = EVENTS.values.map(&:call)
      end
    end
  end
end
