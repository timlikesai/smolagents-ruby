require_relative "events/dsl"
require_relative "events/emitter"
require_relative "events/consumer"
require_relative "events/mappings"
require_relative "events/subscriptions"

module Smolagents
  # Event types for the event-driven architecture.
  #
  # All events are immutable Data.define types with factory methods.
  # They include timestamps and unique IDs for correlation.
  #
  # @example Emitting events
  #   event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
  #   event.step_number  #=> 1
  #   event.outcome      #=> :success
  #
  # @example Consuming events
  #   event = Smolagents::Events::ToolCallCompleted.create(
  #     request_id: "r1", tool_name: "search", result: "data", observation: "found"
  #   )
  #   event.tool_name  #=> "search"
  module Events
    extend DSL

    # Tool execution events
    define_event :ToolCallRequested,
                 fields: %i[tool_name args],
                 freeze: [:args]

    define_event :ToolCallCompleted,
                 fields: %i[request_id tool_name result observation is_final],
                 defaults: { is_final: false }

    # Step execution events
    define_event :StepCompleted,
                 fields: %i[step_number outcome observations],
                 predicates: { success: :success, error: :error, final_answer: :final_answer },
                 defaults: { observations: nil }

    # Task completion events
    define_event :TaskCompleted,
                 fields: %i[outcome output steps_taken],
                 predicates: { success: :success, error: :error, max_steps: :max_steps_reached }

    # Sub-agent lifecycle events
    define_event :SubAgentLaunched,
                 fields: %i[agent_name task parent_id],
                 defaults: { parent_id: nil }

    define_event :SubAgentProgress,
                 fields: %i[launch_id agent_name step_number message]

    define_event :SubAgentCompleted,
                 fields: %i[launch_id agent_name outcome output error token_usage step_count duration],
                 predicates: { success: :success, failure: :failure, error: :error },
                 defaults: { output: nil, error: nil, token_usage: nil, step_count: nil, duration: nil }

    # Error and resilience events
    define_event :ErrorOccurred,
                 fields: %i[error_class error_message context recoverable],
                 freeze: [:context],
                 from_error: true,
                 defaults: { context: {}, recoverable: false }

    # Add predicate methods to ErrorOccurred
    ErrorOccurred.define_method(:recoverable?) { recoverable }
    ErrorOccurred.define_method(:fatal?) { !recoverable }

    define_event :RateLimitHit,
                 fields: %i[tool_name retry_after original_request]

    define_event :RetryRequested,
                 fields: %i[model_id error_class error_message attempt max_attempts suggested_interval],
                 from_error: true

    define_event :FailoverOccurred,
                 fields: %i[from_model_id to_model_id error_class error_message attempt],
                 from_error: true

    define_event :RecoveryCompleted,
                 fields: %i[model_id attempts_before_recovery]

    # Evaluation phase events (metacognition)
    define_event :EvaluationCompleted,
                 fields: %i[step_number status answer reasoning token_usage],
                 predicates: { goal_achieved: :goal_achieved, continue: :continue, stuck: :stuck },
                 predicate_field: :status,
                 defaults: { answer: nil, reasoning: nil, token_usage: nil }

    # Control flow events for Fiber-based bidirectional execution
    define_event :ControlYielded,
                 fields: %i[request_type request_id prompt],
                 predicates: { user_input: :user_input, confirmation: :confirmation,
                               sub_agent_query: :sub_agent_query },
                 predicate_field: :request_type

    define_event :ControlResumed,
                 fields: %i[request_id approved value],
                 defaults: { value: nil }
  end
end
