module Smolagents
  module Events
    # Maps convenience names to event classes for builder DSLs.
    #
    # Enables type-safe event handling with ergonomic builder syntax:
    #
    # @example Using convenience names
    #   agent = Smolagents.agent(:code)
    #     .on(:step_complete) { |e| log(e) }  # Resolves to StepCompleted
    #     .on(:error) { |e| alert(e) }        # Resolves to ErrorOccurred
    #     .build
    #
    # @example Using event classes directly (more explicit)
    #   agent = Smolagents.agent(:code)
    #     .on(Events::StepCompleted) { |e| log(e.step_number) }
    #     .on(Events::ErrorOccurred) { |e| alert(e.error_message) }
    #     .build
    #
    module Mappings
      # Event name -> Event class mapping
      EVENTS = {
        # Tool events
        tool_call: -> { ToolCallRequested },
        tool_complete: -> { ToolCallCompleted },

        # Model events
        model_generate: -> { ModelGenerateRequested },
        model_complete: -> { ModelGenerateCompleted },

        # Step/Task events
        step_complete: -> { StepCompleted },
        task_complete: -> { TaskCompleted },

        # Sub-agent events
        agent_launch: -> { SubAgentLaunched },
        agent_progress: -> { SubAgentProgress },
        agent_complete: -> { SubAgentCompleted },

        # Rate limiting
        rate_limit: -> { RateLimitHit },

        # Errors
        error: -> { ErrorOccurred },

        # Reliability events
        retry: -> { RetryRequested },
        failover: -> { FailoverOccurred },
        recovery: -> { RecoveryCompleted },

        # Supervision
        expired: -> { EventExpired }
      }.freeze

      # Legacy aliases for backwards compatibility
      ALIASES = {
        before_step: :step_complete,
        after_step: :step_complete,
        before_task: :task_complete,
        after_task: :task_complete,
        step_start: :step_complete,
        task_start: :task_complete,
        agent_call: :agent_launch
      }.freeze

      class << self
        # Resolve a name or class to an event class.
        #
        # @param name_or_class [Symbol, Class] Event name or class
        # @return [Class] Event class
        # @raise [ArgumentError] If name is unknown
        def resolve(name_or_class)
          return name_or_class if name_or_class.is_a?(Class)

          name = ALIASES[name_or_class] || name_or_class
          factory = EVENTS[name]

          raise ArgumentError, "Unknown event: #{name_or_class}. Valid: #{EVENTS.keys.join(", ")}" unless factory

          factory.call
        end

        # Check if a name or class is a valid event.
        #
        # @param name_or_class [Symbol, Class] Event name or class
        # @return [Boolean] True if valid
        def valid?(name_or_class)
          return true if name_or_class.is_a?(Class)

          name = ALIASES[name_or_class] || name_or_class
          EVENTS.key?(name)
        end

        # List all event names.
        #
        # @return [Array<Symbol>] Event names
        def names = EVENTS.keys

        # List all event classes.
        #
        # @return [Array<Class>] Event classes
        def classes = EVENTS.values.map(&:call)
      end
    end
  end
end
