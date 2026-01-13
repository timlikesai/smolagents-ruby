module Smolagents
  module Events
    # Maps convenience names to event classes for builder DSLs.
    #
    # @example Using convenience names
    #   agent.on(:step_complete) { |e| log(e) }
    #   agent.on(:error) { |e| alert(e) }
    #
    module Mappings
      EVENTS = {
        tool_call: -> { ToolCallRequested },
        tool_complete: -> { ToolCallCompleted },
        model_generate: -> { ModelGenerateRequested },
        model_complete: -> { ModelGenerateCompleted },
        step_complete: -> { StepCompleted },
        task_complete: -> { TaskCompleted },
        agent_launch: -> { SubAgentLaunched },
        agent_progress: -> { SubAgentProgress },
        agent_complete: -> { SubAgentCompleted },
        error: -> { ErrorOccurred },
        rate_limit: -> { RateLimitHit },
        retry: -> { RetryRequested },
        failover: -> { FailoverOccurred },
        recovery: -> { RecoveryCompleted }
      }.freeze

      class << self
        def resolve(name_or_class)
          return name_or_class if name_or_class.is_a?(Class)

          factory = EVENTS[name_or_class]
          raise ArgumentError, "Unknown event: #{name_or_class}. Valid: #{EVENTS.keys.join(", ")}" unless factory

          factory.call
        end

        def valid?(name_or_class)
          return true if name_or_class.is_a?(Class)

          EVENTS.key?(name_or_class)
        end

        def names = EVENTS.keys
        def classes = EVENTS.values.map(&:call)
      end
    end
  end
end
