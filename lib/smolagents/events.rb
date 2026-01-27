require_relative "events/dsl"
require_relative "events/registry"
require_relative "events/async_queue"
require_relative "events/base"
require_relative "events/emitter"
require_relative "events/consumer"
require_relative "events/subscriptions"
require_relative "events/store"
# NOTE: eventful.rb is now documentation only - components include Emitter + Consumer separately

# rubocop:disable Metrics/ModuleLength -- event definitions file
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

    define_event :ToolCallParsed,
                 fields: %i[model_id tool_name arguments call_id],
                 freeze: [:arguments]

    # Step execution events
    define_event :StepCompleted,
                 fields: %i[step_number outcome observations],
                 predicates: { success: :success, error: :error, final_answer: :final_answer },
                 defaults: { observations: nil }

    # Task lifecycle events
    # Note: TaskStarted is defined in events/orchestration.rb with additional fields

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

    # Spawn restriction events (privilege escalation prevention)
    define_event :SpawnRestricted,
                 fields: %i[agent_name depth violations spawn_path],
                 freeze: [:violations],
                 defaults: { agent_name: nil }

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
                 fields: %i[step_number status answer reasoning confidence token_usage],
                 predicates: { goal_achieved: :goal_achieved, continue: :continue, stuck: :stuck },
                 predicate_field: :status,
                 defaults: { answer: nil, reasoning: nil, confidence: nil, token_usage: nil }

    # Refinement events (self-refine loop)
    define_event :RefinementCompleted,
                 fields: %i[iterations improved confidence],
                 defaults: { confidence: nil }

    # Mixed refinement events (cross-model feedback)
    define_event :MixedRefinementCompleted,
                 fields: %i[iterations improved cross_model],
                 predicates: { cross_model: true },
                 predicate_field: :cross_model

    # Reflection events (learning from failures)
    define_event :ReflectionRecorded,
                 fields: %i[outcome reflection],
                 predicates: { failure: :failure, success: :success },
                 predicate_field: :outcome

    # Goal drift events (task adherence)
    define_event :GoalDriftDetected,
                 fields: %i[level task_relevance off_topic_count],
                 predicates: { mild: :mild, moderate: :moderate, severe: :severe },
                 predicate_field: :level

    # Completion validation events
    define_event :CompletionRejected,
                 fields: %i[reason guidance],
                 defaults: { guidance: nil }

    # Plan divergence events (Pre-Act planning)
    define_event :PlanDivergence,
                 fields: %i[level task_relevance off_topic_count],
                 predicates: { mild: :mild, moderate: :moderate, severe: :severe },
                 predicate_field: :level

    # Control flow events for Fiber-based bidirectional execution
    define_event :ControlYielded,
                 fields: %i[request_type request_id prompt],
                 predicates: { user_input: :user_input, confirmation: :confirmation,
                               sub_agent_query: :sub_agent_query },
                 predicate_field: :request_type

    define_event :ControlResumed,
                 fields: %i[request_id approved value],
                 defaults: { value: nil }

    # Repetition detection events (loop prevention)
    define_event :RepetitionDetected,
                 fields: %i[pattern count guidance],
                 predicates: { tool_call: :tool_call, code_action: :code_action, observation: :observation },
                 predicate_field: :pattern

    # Tool Isolation Events
    define_event :ToolIsolationStarted,
                 fields: %i[tool_name isolation_mode resource_limits],
                 freeze: [:resource_limits]

    define_event :ToolIsolationCompleted,
                 fields: %i[tool_name outcome metrics error_class],
                 predicates: { success: :success, timeout: :timeout, violation: :violation, error: :error },
                 freeze: [:metrics],
                 defaults: { error_class: nil }

    define_event :ResourceViolation,
                 fields: %i[tool_name resource_type limit_value actual_value message],
                 predicates: { memory: :memory, timeout: :timeout, output: :output },
                 predicate_field: :resource_type

    # Model generation events
    define_event :ModelGenerateRequested,
                 fields: %i[model_id message_count has_tools temperature],
                 defaults: { has_tools: false, temperature: nil }

    define_event :ModelGenerateCompleted,
                 fields: %i[model_id duration_ms token_usage has_tool_calls outcome],
                 predicates: { success: :success, error: :error },
                 freeze: [:token_usage],
                 defaults: { token_usage: nil, has_tool_calls: false, outcome: :success }

    # Goal tracking events
    define_event :GoalCreated,
                 fields: %i[goal parent_id],
                 defaults: { parent_id: nil }

    define_event :GoalProgress,
                 fields: %i[goal previous_progress],
                 defaults: { previous_progress: nil }

    define_event :GoalCompleted,
                 fields: %i[goal evidence]

    # Planning events (Pre-Act pattern)
    define_event :PlanGenerated,
                 fields: %i[plan step_count model_id],
                 defaults: { model_id: nil }

    define_event :PlanUpdated,
                 fields: %i[plan previous_plan reason step_number],
                 defaults: { reason: nil }

    # Code execution events (executor-level)
    define_event :CodeGenerated,
                 fields: %i[code language step_number model_id]

    define_event :CodeExecutionStarted,
                 fields: %i[code_hash isolation_mode]

    define_event :CodeExecutionFinished,
                 fields: %i[code_hash outcome duration_ms output error_class],
                 predicates: { success: :success, error: :error, timeout: :timeout },
                 defaults: { error_class: nil, output: nil }

    # Builder configuration events
    define_event :AgentConfigured,
                 fields: %i[agent_name tools model_purposes],
                 freeze: %i[tools model_purposes]
  end
end
# rubocop:enable Metrics/ModuleLength

# Load additional event categories after module is defined
require_relative "events/reliability"
require_relative "events/orchestration"
require_relative "events/phase_d"
require_relative "events/mappings"
