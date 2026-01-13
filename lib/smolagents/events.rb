require_relative "events/emitter"
require_relative "events/consumer"
require_relative "events/mappings"

module Smolagents
  # Event types for the event-driven architecture.
  #
  # All operations emit events that handlers can process. Events are immutable
  # Data.define types with factory methods for creation.
  #
  # @example
  #   event = Events::StepCompleted.create(step_number: 1, outcome: :success)
  #
  module Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Tool Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ToolCallRequested = Data.define(:id, :tool_name, :args, :created_at) do
      def self.create(tool_name:, args:)
        new(id: SecureRandom.uuid, tool_name:, args: args.freeze, created_at: Time.now)
      end
    end

    ToolCallCompleted = Data.define(:id, :request_id, :tool_name, :result, :observation, :is_final, :created_at) do
      def self.create(request_id:, tool_name:, result:, observation:, is_final: false)
        new(id: SecureRandom.uuid, request_id:, tool_name:, result:, observation:, is_final:, created_at: Time.now)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Model Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ModelGenerateRequested = Data.define(:id, :model_id, :messages, :tools, :created_at) do
      def self.create(messages:, model_id: nil, tools: nil)
        new(id: SecureRandom.uuid, model_id:, messages: messages.freeze, tools: tools&.freeze, created_at: Time.now)
      end
    end

    ModelGenerateCompleted = Data.define(:id, :request_id, :model_id, :response, :token_usage, :created_at) do
      def self.create(request_id:, response:, model_id: nil, token_usage: nil)
        new(id: SecureRandom.uuid, request_id:, model_id:, response:, token_usage:, created_at: Time.now)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Step/Task Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    StepCompleted = Data.define(:id, :step_number, :outcome, :observations, :created_at) do
      def self.create(step_number:, outcome:, observations: nil)
        new(id: SecureRandom.uuid, step_number:, outcome:, observations:, created_at: Time.now)
      end

      def success? = outcome == :success
      def error? = outcome == :error
      def final_answer? = outcome == :final_answer
    end

    TaskCompleted = Data.define(:id, :outcome, :output, :steps_taken, :created_at) do
      def self.create(outcome:, output:, steps_taken:)
        new(id: SecureRandom.uuid, outcome:, output:, steps_taken:, created_at: Time.now)
      end

      def success? = outcome == :success
      def max_steps? = outcome == :max_steps
      def error? = outcome == :error
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Sub-Agent Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SubAgentLaunched = Data.define(:id, :agent_name, :task, :parent_id, :created_at) do
      def self.create(agent_name:, task:, parent_id: nil)
        new(id: SecureRandom.uuid, agent_name:, task:, parent_id:, created_at: Time.now)
      end
    end

    SubAgentProgress = Data.define(:id, :launch_id, :agent_name, :step_number, :message, :created_at) do
      def self.create(launch_id:, agent_name:, step_number:, message:)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, step_number:, message:, created_at: Time.now)
      end
    end

    SubAgentCompleted = Data.define(:id, :launch_id, :agent_name, :outcome, :output, :error, :created_at) do
      def self.create(launch_id:, agent_name:, outcome:, output: nil, error: nil)
        new(id: SecureRandom.uuid, launch_id:, agent_name:, outcome:, output:, error:, created_at: Time.now)
      end

      def success? = outcome == :success
      def failure? = outcome == :failure
      def error? = outcome == :error
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Error Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ErrorOccurred = Data.define(:id, :error_class, :error_message, :context, :recoverable, :created_at) do
      def self.create(error:, context: {}, recoverable: false)
        new(id: SecureRandom.uuid, error_class: error.class.name, error_message: error.message, context: context.freeze, recoverable:, created_at: Time.now)
      end

      def recoverable? = recoverable
      def fatal? = !recoverable
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Rate Limiting
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    RateLimitHit = Data.define(:id, :tool_name, :retry_after, :original_request, :created_at) do
      def self.create(tool_name:, retry_after:, original_request:)
        new(id: SecureRandom.uuid, tool_name:, retry_after:, original_request:, created_at: Time.now)
      end
    end

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # Reliability Events
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    RetryRequested = Data.define(:id, :model_id, :error_class, :error_message, :attempt, :max_attempts, :suggested_interval, :created_at) do
      def self.create(model_id:, error:, attempt:, max_attempts:, suggested_interval:)
        new(id: SecureRandom.uuid, model_id:, error_class: error.class.name, error_message: error.message, attempt:, max_attempts:, suggested_interval:, created_at: Time.now)
      end
    end

    FailoverOccurred = Data.define(:id, :from_model_id, :to_model_id, :error_class, :error_message, :attempt, :created_at) do
      def self.create(from_model_id:, to_model_id:, error:, attempt:)
        new(id: SecureRandom.uuid, from_model_id:, to_model_id:, error_class: error.class.name, error_message: error.message, attempt:, created_at: Time.now)
      end
    end

    RecoveryCompleted = Data.define(:id, :model_id, :attempts_before_recovery, :created_at) do
      def self.create(model_id:, attempts_before_recovery:)
        new(id: SecureRandom.uuid, model_id:, attempts_before_recovery:, created_at: Time.now)
      end
    end
  end
end
