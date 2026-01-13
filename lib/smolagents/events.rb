require_relative "events/event_queue"
require_relative "events/scheduler"
require_relative "events/emitter"
require_relative "events/consumer"
require_relative "events/mappings"

module Smolagents
  # Event types for the event-driven ReAct loop architecture.
  #
  # All operations emit events that the master loop processes. Events have:
  # - id: Unique identifier for tracking
  # - created_at: When the event was created
  # - due_at: When the event should be processed (nil = immediate)
  #
  # @example Creating events
  #   event = Events::ToolCallRequested.create(tool_name: "search", args: { query: "test" })
  #   event.ready?      # => true (no due_at means immediate)
  #
  module Events
    # Mixin for common event behavior
    module EventBehavior
      def ready? = due_at.nil? || Time.now >= due_at
      def past_due?(threshold: 60) = due_at && (Time.now - due_at) > threshold
      def wait_time = due_at.nil? ? 0.0 : [due_at - Time.now, 0.0].max
      def immediate? = due_at.nil?
      def scheduled? = !due_at.nil?
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Tool Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ToolCallRequested = Data.define(:id, :tool_name, :args, :created_at, :due_at) do
      include EventBehavior

      def self.create(tool_name:, args:, due_at: nil)
        new(id: SecureRandom.uuid, tool_name:, args: args.freeze, created_at: Time.now, due_at:)
      end
    end

    ToolCallCompleted = Data.define(:id, :request_id, :tool_name, :result, :observation, :is_final, :created_at, :due_at) do
      include EventBehavior

      def self.create(request_id:, tool_name:, result:, observation:, is_final: false)
        new(id: SecureRandom.uuid, request_id:, tool_name:, result:, observation:, is_final:, created_at: Time.now, due_at: nil)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Model Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ModelGenerateRequested = Data.define(:id, :model_id, :messages, :tools, :created_at, :due_at) do
      include EventBehavior

      def self.create(messages:, model_id: nil, tools: nil, due_at: nil)
        new(id: SecureRandom.uuid, model_id:, messages: messages.freeze, tools: tools&.freeze, created_at: Time.now, due_at:)
      end
    end

    ModelGenerateCompleted = Data.define(:id, :request_id, :model_id, :response, :token_usage, :created_at, :due_at) do
      include EventBehavior

      def self.create(request_id:, response:, model_id: nil, token_usage: nil)
        new(id: SecureRandom.uuid, request_id:, model_id:, response:, token_usage:, created_at: Time.now, due_at: nil)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Step/Task Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    StepCompleted = Data.define(:id, :step_number, :outcome, :observations, :created_at, :due_at) do
      include EventBehavior

      def self.create(step_number:, outcome:, observations: nil)
        new(id: SecureRandom.uuid, step_number:, outcome:, observations:, created_at: Time.now, due_at: nil)
      end

      def success? = outcome == :success
      def rate_limited? = outcome == :rate_limited
      def error? = outcome == :error
      def final_answer? = outcome == :final_answer
    end

    TaskCompleted = Data.define(:id, :outcome, :output, :steps_taken, :created_at, :due_at) do
      include EventBehavior

      def self.create(outcome:, output:, steps_taken:)
        new(id: SecureRandom.uuid, outcome:, output:, steps_taken:, created_at: Time.now, due_at: nil)
      end

      def success? = outcome == :success
      def max_steps? = outcome == :max_steps
      def error? = outcome == :error
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Sub-Agent Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SubAgentLaunched = Data.define(:id, :agent_name, :task, :parent_id, :created_at, :due_at) do
      include EventBehavior

      def self.create(agent_name:, task:, parent_id: nil)
        new(id: SecureRandom.uuid, agent_name:, task:, parent_id:, created_at: Time.now, due_at: nil)
      end
    end

    SubAgentProgress = Data.define(:id, :launch_id, :agent_name, :step_number, :message, :created_at, :due_at) do
      include EventBehavior

      def self.create(launch_id:, agent_name:, step_number:, message:)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, step_number:, message:, created_at: Time.now, due_at: nil)
      end
    end

    SubAgentCompleted = Data.define(:id, :launch_id, :agent_name, :outcome, :output, :error, :created_at, :due_at) do
      include EventBehavior

      def self.create(launch_id:, agent_name:, outcome:, output: nil, error: nil)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, outcome:, output:, error:, created_at: Time.now, due_at: nil)
      end

      def success? = outcome == :success
      def failure? = outcome == :failure
      def error? = outcome == :error
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Rate Limiting
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    RateLimitHit = Data.define(:id, :tool_name, :retry_after, :original_request, :created_at) do
      include EventBehavior

      def self.create(tool_name:, retry_after:, original_request:)
        new(id: SecureRandom.uuid, tool_name:, retry_after:, original_request:, created_at: Time.now)
      end

      def due_at = created_at + retry_after
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Error Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ErrorOccurred = Data.define(:id, :error_class, :error_message, :context, :recoverable, :created_at, :due_at) do
      include EventBehavior

      def self.create(error:, context: {}, recoverable: false)
        new(id: SecureRandom.uuid, error_class: error.class.name, error_message: error.message, context: context.freeze, recoverable:, created_at: Time.now, due_at: nil)
      end

      def recoverable? = recoverable
      def fatal? = !recoverable
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Reliability Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    RetryRequested = Data.define(:id, :model_id, :error_class, :error_message, :attempt, :max_attempts, :suggested_interval, :created_at, :due_at) do
      include EventBehavior

      def self.create(model_id:, error:, attempt:, max_attempts:, suggested_interval:)
        new(id: SecureRandom.uuid, model_id:, error_class: error.class.name, error_message: error.message, attempt:, max_attempts:, suggested_interval:, created_at: Time.now,
            due_at: nil)
      end
    end

    FailoverOccurred = Data.define(:id, :from_model_id, :to_model_id, :error_class, :error_message, :attempt, :created_at, :due_at) do
      include EventBehavior

      def self.create(from_model_id:, to_model_id:, error:, attempt:)
        new(id: SecureRandom.uuid, from_model_id:, to_model_id:, error_class: error.class.name, error_message: error.message, attempt:, created_at: Time.now, due_at: nil)
      end
    end

    RecoveryCompleted = Data.define(:id, :model_id, :attempts_before_recovery, :created_at, :due_at) do
      include EventBehavior

      def self.create(model_id:, attempts_before_recovery:)
        new(id: SecureRandom.uuid, model_id:, attempts_before_recovery:, created_at: Time.now, due_at: nil)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Supervision
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    EventExpired = Data.define(:id, :original_event, :age, :created_at, :due_at) do
      include EventBehavior

      def self.create(original_event:, threshold:)
        new(id: SecureRandom.uuid, original_event:, age: Time.now - original_event.due_at, created_at: Time.now, due_at: nil)
      end
    end
  end
end
