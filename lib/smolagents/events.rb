require_relative "events/event_queue"
require_relative "events/scheduler"
require_relative "events/emitter"
require_relative "events/consumer"

module Smolagents
  # Event types for the event-driven ReAct loop architecture.
  #
  # All operations emit events that the master loop processes. Events have:
  # - id: Unique identifier for tracking
  # - created_at: When the event was created
  # - due_at: When the event should be processed (nil = immediate)
  #
  # @example Creating and checking events
  #   event = Events::ToolCallRequested.create(tool_name: "search", args: { query: "test" })
  #   event.ready?      # => true (no due_at means immediate)
  #   event.wait_time   # => 0.0
  #
  # @example Scheduled events
  #   event = Events::RateLimitHit.create(
  #     tool_name: "search",
  #     retry_after: 1.0,
  #     original_request: original
  #   )
  #   event.ready?      # => false (due in 1 second)
  #   event.past_due?   # => false
  #
  module Events
    # Mixin for common event behavior
    module EventBehavior
      def ready?
        due_at.nil? || Time.now >= due_at
      end

      def past_due?(threshold: 60)
        due_at && (Time.now - due_at) > threshold
      end

      def wait_time
        return 0.0 if due_at.nil?

        remaining = due_at - Time.now
        remaining.positive? ? remaining : 0.0
      end

      def immediate?
        due_at.nil?
      end

      def scheduled?
        !due_at.nil?
      end
    end

    # Tool execution requested
    ToolCallRequested = Data.define(:id, :tool_name, :args, :created_at, :due_at) do
      include EventBehavior

      def self.create(tool_name:, args:, due_at: nil)
        new(
          id: SecureRandom.uuid,
          tool_name:,
          args: args.freeze,
          created_at: Time.now,
          due_at:
        )
      end
    end

    # Tool execution completed
    ToolCallCompleted = Data.define(:id, :request_id, :tool_name, :result, :observation, :is_final, :created_at, :due_at) do
      include EventBehavior

      def self.create(request_id:, tool_name:, result:, observation:, is_final: false)
        new(
          id: SecureRandom.uuid,
          request_id:,
          tool_name:,
          result:,
          observation:,
          is_final:,
          created_at: Time.now,
          due_at: nil
        )
      end
    end

    # Rate limit hit - reschedule for later
    RateLimitHit = Data.define(:id, :tool_name, :retry_after, :original_request, :created_at) do
      include EventBehavior

      def self.create(tool_name:, retry_after:, original_request:)
        new(
          id: SecureRandom.uuid,
          tool_name:,
          retry_after:,
          original_request:,
          created_at: Time.now
        )
      end

      def due_at
        created_at + retry_after
      end
    end

    # Model generation requested
    ModelGenerateRequested = Data.define(:id, :messages, :tools, :created_at, :due_at) do
      include EventBehavior

      def self.create(messages:, tools: nil, due_at: nil)
        new(
          id: SecureRandom.uuid,
          messages: messages.freeze,
          tools: tools&.freeze,
          created_at: Time.now,
          due_at:
        )
      end
    end

    # Model generation completed
    ModelGenerateCompleted = Data.define(:id, :request_id, :response, :token_usage, :created_at, :due_at) do
      include EventBehavior

      def self.create(request_id:, response:, token_usage: nil)
        new(
          id: SecureRandom.uuid,
          request_id:,
          response:,
          token_usage:,
          created_at: Time.now,
          due_at: nil
        )
      end
    end

    # Step completed
    StepCompleted = Data.define(:id, :step_number, :outcome, :observations, :created_at, :due_at) do
      include EventBehavior

      def self.create(step_number:, outcome:, observations: nil)
        new(
          id: SecureRandom.uuid,
          step_number:,
          outcome:,
          observations:,
          created_at: Time.now,
          due_at: nil
        )
      end

      def success? = outcome == :success
      def rate_limited? = outcome == :rate_limited
      def error? = outcome == :error
      def final_answer? = outcome == :final_answer
    end

    # Task finished
    TaskCompleted = Data.define(:id, :outcome, :output, :steps_taken, :created_at, :due_at) do
      include EventBehavior

      def self.create(outcome:, output:, steps_taken:)
        new(
          id: SecureRandom.uuid,
          outcome:,
          output:,
          steps_taken:,
          created_at: Time.now,
          due_at: nil
        )
      end

      def success? = outcome == :success
      def max_steps? = outcome == :max_steps
      def error? = outcome == :error
    end

    # Error occurred
    ErrorOccurred = Data.define(:id, :error_class, :error_message, :context, :recoverable, :created_at, :due_at) do
      include EventBehavior

      def self.create(error:, context: {}, recoverable: false)
        new(
          id: SecureRandom.uuid,
          error_class: error.class.name,
          error_message: error.message,
          context: context.freeze,
          recoverable:,
          created_at: Time.now,
          due_at: nil
        )
      end

      def recoverable? = recoverable
      def fatal? = !recoverable
    end

    # Event expired (past due threshold)
    EventExpired = Data.define(:id, :original_event, :age, :created_at, :due_at) do
      include EventBehavior

      def self.create(original_event:, threshold:)
        new(
          id: SecureRandom.uuid,
          original_event:,
          age: Time.now - original_event.due_at,
          created_at: Time.now,
          due_at: nil
        )
      end
    end
  end
end
