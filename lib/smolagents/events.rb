require_relative "events/emitter"
require_relative "events/consumer"
require_relative "events/mappings"

module Smolagents
  # Event types and infrastructure for the event-driven architecture.
  #
  # Smolagents uses an event-driven design where all operations (tool calls,
  # steps, errors, etc.) emit immutable events that observers can process.
  # This enables:
  #
  # - **Observability**: Understand agent execution in detail
  # - **Logging**: Track all operations without coupling
  # - **Metrics**: Collect data on tool calls, durations, errors
  # - **Tracing**: Generate distributed traces with OpenTelemetry
  # - **Debugging**: Step through execution history
  #
  # Events are immutable Data.define types with factory methods for creation.
  # They include timestamps and unique IDs for correlation.
  #
  # @example Creating and emitting events
  #   event = Events::StepCompleted.create(step_number: 1, outcome: :success)
  #   emitter.emit(event)
  #
  # @example Consuming events
  #   agent.on(:step_complete) { |e| log("Step #{e.step_number}") }
  #   agent.on(Events::ErrorOccurred) { |e| alert(e.error_message) }
  #
  # @example Using with observability
  #   Telemetry::LoggingSubscriber.enable
  #   agent.run("task")  # All events logged automatically
  #
  # @see Emitter For emitting events
  # @see Consumer For consuming events
  # @see Mappings For event name resolution
  # @see Telemetry For observability integration
  #
  module Events
    # Tool call events track requests and completions.
    #
    # Emitted when a tool is about to be called and when it completes.
    # Used for monitoring tool usage, performance, and errors.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID (UUID)
    # @!attribute [r] tool_name
    #   @return [String] Name of the tool being called
    # @!attribute [r] args
    #   @return [Hash] Arguments passed to the tool
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    ToolCallRequested = Data.define(:id, :tool_name, :args, :created_at) do
      # Creates a ToolCallRequested event.
      #
      # @param tool_name [String] Name of the tool being called
      # @param args [Hash] Arguments for the tool
      # @return [ToolCallRequested] New event instance
      def self.create(tool_name:, args:)
        new(id: SecureRandom.uuid, tool_name:, args: args.freeze, created_at: Time.now)
      end
    end

    # Tool call completion event with result and observation.
    #
    # Emitted when a tool call completes (success or failure).
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] request_id
    #   @return [String] ID of the corresponding ToolCallRequested
    # @!attribute [r] tool_name
    #   @return [String] Name of the completed tool
    # @!attribute [r] result
    #   @return [Object] The tool's return value
    # @!attribute [r] observation
    #   @return [String] Human-readable observation of the result
    # @!attribute [r] is_final
    #   @return [Boolean] Whether this is a final_answer result
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    ToolCallCompleted = Data.define(:id, :request_id, :tool_name, :result, :observation, :is_final, :created_at) do
      # Creates a ToolCallCompleted event.
      #
      # @param request_id [String] ID of the ToolCallRequested event
      # @param tool_name [String] Name of the completed tool
      # @param result [Object] The tool's return value
      # @param observation [String] Human-readable observation
      # @param is_final [Boolean] Whether this is a final answer (default: false)
      # @return [ToolCallCompleted] New event instance
      def self.create(request_id:, tool_name:, result:, observation:, is_final: false)
        new(id: SecureRandom.uuid, request_id:, tool_name:, result:, observation:, is_final:, created_at: Time.now)
      end
    end

    # Step execution events track individual agent reasoning steps.
    #
    # Emitted when each ReAct loop iteration completes.
    # Used to monitor progress through a task.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] step_number
    #   @return [Integer] The step number (1-indexed)
    # @!attribute [r] outcome
    #   @return [Symbol] Result (:success, :error, :final_answer)
    # @!attribute [r] observations
    #   @return [Array, nil] Tool observations from this step
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    StepCompleted = Data.define(:id, :step_number, :outcome, :observations, :created_at) do
      # Creates a StepCompleted event.
      #
      # @param step_number [Integer] The step number
      # @param outcome [Symbol] Result of the step (:success, :error, :final_answer)
      # @param observations [Array, nil] Tool observations (default: nil)
      # @return [StepCompleted] New event instance
      def self.create(step_number:, outcome:, observations: nil)
        new(id: SecureRandom.uuid, step_number:, outcome:, observations:, created_at: Time.now)
      end

      # Checks if step completed successfully.
      # @return [Boolean] True if outcome is :success
      def success? = outcome == :success

      # Checks if step ended with an error.
      # @return [Boolean] True if outcome is :error
      def error? = outcome == :error

      # Checks if step produced a final answer.
      # @return [Boolean] True if outcome is :final_answer
      def final_answer? = outcome == :final_answer
    end

    # Task completion event with final result.
    #
    # Emitted when an agent finishes executing a task (success, error, or max steps).
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] outcome
    #   @return [Symbol] Result (:success, :error, :max_steps_reached)
    # @!attribute [r] output
    #   @return [String, nil] The task's final output/answer
    # @!attribute [r] steps_taken
    #   @return [Integer] Total number of steps executed
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    TaskCompleted = Data.define(:id, :outcome, :output, :steps_taken, :created_at) do
      # Creates a TaskCompleted event.
      #
      # @param outcome [Symbol] Result (:success, :error, :max_steps_reached)
      # @param output [String, nil] The task's final output
      # @param steps_taken [Integer] Total steps executed
      # @return [TaskCompleted] New event instance
      def self.create(outcome:, output:, steps_taken:)
        new(id: SecureRandom.uuid, outcome:, output:, steps_taken:, created_at: Time.now)
      end

      # Checks if task completed successfully.
      # @return [Boolean] True if outcome is :success
      def success? = outcome == :success

      # Checks if task hit max steps limit.
      # @return [Boolean] True if outcome is :max_steps_reached
      def max_steps? = outcome == :max_steps_reached

      # Checks if task ended with an error.
      # @return [Boolean] True if outcome is :error
      def error? = outcome == :error
    end

    # Sub-agent lifecycle events for team orchestration.
    #
    # Emitted when sub-agents are launched, progress, and complete in team scenarios.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] agent_name
    #   @return [String] Name of the sub-agent
    # @!attribute [r] task
    #   @return [String] Task assigned to the sub-agent
    # @!attribute [r] parent_id
    #   @return [String, nil] ID of parent orchestrator agent
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    SubAgentLaunched = Data.define(:id, :agent_name, :task, :parent_id, :created_at) do
      # Creates a SubAgentLaunched event.
      #
      # @param agent_name [String] Name of the sub-agent
      # @param task [String] Task for the sub-agent
      # @param parent_id [String, nil] Parent orchestrator ID (default: nil)
      # @return [SubAgentLaunched] New event instance
      def self.create(agent_name:, task:, parent_id: nil)
        new(id: SecureRandom.uuid, agent_name:, task:, parent_id:, created_at: Time.now)
      end
    end

    # Sub-agent progress event during execution.
    #
    # Emitted periodically during sub-agent execution for progress tracking.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] launch_id
    #   @return [String] ID of the SubAgentLaunched event
    # @!attribute [r] agent_name
    #   @return [String] Name of the sub-agent
    # @!attribute [r] step_number
    #   @return [Integer] Current step number
    # @!attribute [r] message
    #   @return [String] Progress message
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    SubAgentProgress = Data.define(:id, :launch_id, :agent_name, :step_number, :message, :created_at) do
      # Creates a SubAgentProgress event.
      #
      # @param launch_id [String] ID of the SubAgentLaunched event
      # @param agent_name [String] Name of the sub-agent
      # @param step_number [Integer] Current step number
      # @param message [String] Progress message
      # @return [SubAgentProgress] New event instance
      def self.create(launch_id:, agent_name:, step_number:, message:)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, step_number:, message:, created_at: Time.now)
      end
    end

    # Sub-agent completion event with result.
    #
    # Emitted when a sub-agent finishes executing its task.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] launch_id
    #   @return [String] ID of the SubAgentLaunched event
    # @!attribute [r] agent_name
    #   @return [String] Name of the completed sub-agent
    # @!attribute [r] outcome
    #   @return [Symbol] Result (:success, :failure, :error)
    # @!attribute [r] output
    #   @return [String, nil] The sub-agent's output
    # @!attribute [r] error
    #   @return [String, nil] Error message if outcome is :error
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    SubAgentCompleted = Data.define(:id, :launch_id, :agent_name, :outcome, :output, :error, :created_at) do
      # Creates a SubAgentCompleted event.
      #
      # @param launch_id [String] ID of the SubAgentLaunched event
      # @param agent_name [String] Name of the completed sub-agent
      # @param outcome [Symbol] Result (:success, :failure, :error)
      # @param output [String, nil] The sub-agent's output (default: nil)
      # @param error [String, nil] Error message (default: nil)
      # @return [SubAgentCompleted] New event instance
      def self.create(launch_id:, agent_name:, outcome:, output: nil, error: nil)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, outcome:, output:, error:, created_at: Time.now)
      end

      # Checks if sub-agent succeeded.
      # @return [Boolean] True if outcome is :success
      def success? = outcome == :success

      # Checks if sub-agent failed.
      # @return [Boolean] True if outcome is :failure
      def failure? = outcome == :failure

      # Checks if sub-agent encountered an error.
      # @return [Boolean] True if outcome is :error
      def error? = outcome == :error
    end

    # Error event for exception handling and alerting.
    #
    # Emitted when an exception occurs during agent execution.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] error_class
    #   @return [String] Exception class name
    # @!attribute [r] error_message
    #   @return [String] Exception message
    # @!attribute [r] context
    #   @return [Hash] Additional context about the error
    # @!attribute [r] recoverable
    #   @return [Boolean] Whether the error can be recovered from
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    ErrorOccurred = Data.define(:id, :error_class, :error_message, :context, :recoverable, :created_at) do
      # Creates an ErrorOccurred event.
      #
      # @param error [Exception] The exception that occurred
      # @param context [Hash] Additional context (default: {})
      # @param recoverable [Boolean] Whether recoverable (default: false)
      # @return [ErrorOccurred] New event instance
      def self.create(error:, context: {}, recoverable: false)
        new(id: SecureRandom.uuid, error_class: error.class.name, error_message: error.message,
            context: context.freeze, recoverable:, created_at: Time.now)
      end

      # Checks if error is recoverable.
      # @return [Boolean] True if recoverable
      def recoverable? = recoverable

      # Checks if error is fatal (not recoverable).
      # @return [Boolean] True if not recoverable
      def fatal? = !recoverable
    end

    # Rate limit event for API throttling.
    #
    # Emitted when a tool receives a rate limit response from an API.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] tool_name
    #   @return [String] Name of the tool that hit the rate limit
    # @!attribute [r] retry_after
    #   @return [Integer] Seconds to wait before retrying
    # @!attribute [r] original_request
    #   @return [Hash] The request that was rate limited
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    RateLimitHit = Data.define(:id, :tool_name, :retry_after, :original_request, :created_at) do
      # Creates a RateLimitHit event.
      #
      # @param tool_name [String] Name of the tool
      # @param retry_after [Integer] Seconds until retry
      # @param original_request [Hash] The rate-limited request
      # @return [RateLimitHit] New event instance
      def self.create(tool_name:, retry_after:, original_request:)
        new(id: SecureRandom.uuid, tool_name:, retry_after:, original_request:, created_at: Time.now)
      end
    end

    # Retry event for failed model operations.
    #
    # Emitted when a model operation is retried after failure.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] model_id
    #   @return [String] ID of the model being retried
    # @!attribute [r] error_class
    #   @return [String] Exception class that triggered retry
    # @!attribute [r] error_message
    #   @return [String] Exception message
    # @!attribute [r] attempt
    #   @return [Integer] Current attempt number
    # @!attribute [r] max_attempts
    #   @return [Integer] Maximum allowed attempts
    # @!attribute [r] suggested_interval
    #   @return [Float] Suggested wait time in seconds
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    RetryRequested = Data.define(:id, :model_id, :error_class, :error_message, :attempt, :max_attempts,
                                 :suggested_interval, :created_at) do
      # Creates a RetryRequested event.
      #
      # @param model_id [String] ID of the model
      # @param error [Exception] The error triggering retry
      # @param attempt [Integer] Current attempt number
      # @param max_attempts [Integer] Maximum attempts
      # @param suggested_interval [Float] Suggested wait time
      # @return [RetryRequested] New event instance
      def self.create(model_id:, error:, attempt:, max_attempts:, suggested_interval:)
        new(id: SecureRandom.uuid, model_id:, error_class: error.class.name, error_message: error.message, attempt:,
            max_attempts:, suggested_interval:, created_at: Time.now)
      end
    end

    # Failover event for multi-model recovery.
    #
    # Emitted when a request is switched to a failover model after failure.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] from_model_id
    #   @return [String] ID of the failed model
    # @!attribute [r] to_model_id
    #   @return [String] ID of the failover model
    # @!attribute [r] error_class
    #   @return [String] Exception class that triggered failover
    # @!attribute [r] error_message
    #   @return [String] Exception message
    # @!attribute [r] attempt
    #   @return [Integer] Attempt number when failover occurred
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    FailoverOccurred = Data.define(:id, :from_model_id, :to_model_id, :error_class, :error_message, :attempt,
                                   :created_at) do
      # Creates a FailoverOccurred event.
      #
      # @param from_model_id [String] ID of failed model
      # @param to_model_id [String] ID of failover model
      # @param error [Exception] Error that triggered failover
      # @param attempt [Integer] Attempt number
      # @return [FailoverOccurred] New event instance
      def self.create(from_model_id:, to_model_id:, error:, attempt:)
        new(id: SecureRandom.uuid, from_model_id:, to_model_id:, error_class: error.class.name,
            error_message: error.message, attempt:, created_at: Time.now)
      end
    end

    # Recovery completion event.
    #
    # Emitted when a failed model recovers after retries or failover.
    #
    # @!attribute [r] id
    #   @return [String] Unique event ID
    # @!attribute [r] model_id
    #   @return [String] ID of the recovered model
    # @!attribute [r] attempts_before_recovery
    #   @return [Integer] Number of attempts before recovery
    # @!attribute [r] created_at
    #   @return [Time] Event creation timestamp
    #
    RecoveryCompleted = Data.define(:id, :model_id, :attempts_before_recovery, :created_at) do
      # Creates a RecoveryCompleted event.
      #
      # @param model_id [String] ID of recovered model
      # @param attempts_before_recovery [Integer] Attempts before recovery
      # @return [RecoveryCompleted] New event instance
      def self.create(model_id:, attempts_before_recovery:)
        new(id: SecureRandom.uuid, model_id:, attempts_before_recovery:, created_at: Time.now)
      end
    end
  end
end
