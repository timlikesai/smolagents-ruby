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
                 freeze: [:args],
                 category: :tools, description: "Fired when a tool is about to be called",
                 tier: :user

    define_event :ToolCallCompleted,
                 fields: %i[request_id tool_name result observation is_final correlation_id],
                 defaults: { is_final: false, correlation_id: nil },
                 category: :tools, description: "Fired after a tool execution completes",
                 tier: :user

    define_event :ToolCallParsed,
                 fields: %i[model_id tool_name arguments call_id],
                 freeze: [:arguments],
                 category: :models, description: "Fired when a tool call is parsed from model output",
                 tier: :user

    # Step execution events
    define_event :StepCompleted,
                 fields: %i[step_number outcome observations token_usage context_usage_percent correlation_id],
                 predicates: { success: :success, error: :error, final_answer: :final_answer },
                 defaults: { observations: nil, token_usage: nil, context_usage_percent: nil, correlation_id: nil },
                 category: :lifecycle, description: "Fired after each ReAct loop step completes",
                 tier: :user

    # Task lifecycle events (consolidated: TaskStarted + TaskCompleted)
    define_event :TaskLifecycle,
                 fields: %i[phase task agent_name max_steps run_id outcome output steps_taken],
                 predicates: { started: :started, completed: :completed },
                 predicate_field: :phase,
                 defaults: { task: nil, agent_name: nil, max_steps: nil, run_id: nil,
                             outcome: nil, output: nil, steps_taken: nil },
                 category: :lifecycle, description: "Fired during task lifecycle transitions",
                 tier: :user

    # Sub-agent lifecycle events
    define_event :SubAgentLaunched,
                 fields: %i[agent_name task parent_id depth],
                 defaults: { parent_id: nil, depth: 0 },
                 category: :subagents, description: "Fired when a sub-agent is launched",
                 tier: :user

    define_event :SubAgentProgress,
                 fields: %i[launch_id agent_name step_number message],
                 category: :subagents, description: "Fired when a sub-agent makes progress"

    define_event :SubAgentCompleted,
                 fields: %i[launch_id agent_name outcome output error token_usage step_count duration depth],
                 predicates: { success: :success, failure: :failure, error: :error },
                 defaults: { output: nil, error: nil, token_usage: nil, step_count: nil, duration: nil, depth: 0 },
                 category: :subagents, description: "Fired when a sub-agent completes",
                 tier: :user

    # Spawn restriction events (privilege escalation prevention)
    define_event :SpawnRestricted,
                 fields: %i[agent_name depth violations spawn_path],
                 freeze: [:violations],
                 defaults: { agent_name: nil },
                 category: :subagents, description: "Fired when a spawn request is denied by policy"

    # Error and resilience events
    define_event :ErrorOccurred,
                 fields: %i[error_class error_message context recoverable],
                 freeze: [:context],
                 from_error: true,
                 defaults: { context: {}, recoverable: false },
                 category: :errors, description: "Fired when an error occurs",
                 tier: :user

    # Add predicate methods to ErrorOccurred
    ErrorOccurred.define_method(:recoverable?) { recoverable }
    ErrorOccurred.define_method(:fatal?) { !recoverable }

    define_event :RetryRequested,
                 fields: %i[model_id error_class error_message attempt max_attempts suggested_interval],
                 from_error: true,
                 category: :resilience, description: "Fired when a retry is requested"

    define_event :FailoverOccurred,
                 fields: %i[from_model_id to_model_id error_class error_message attempt],
                 from_error: true,
                 category: :resilience, description: "Fired when failover to a backup model occurs"

    define_event :RecoveryCompleted,
                 fields: %i[model_id attempts_before_recovery],
                 category: :resilience, description: "Fired when a model recovers from failures"

    # Evaluation phase events (metacognition)
    define_event :EvaluationCompleted,
                 fields: %i[step_number status answer reasoning confidence token_usage],
                 predicates: { goal_achieved: :goal_achieved, continue: :continue, stuck: :stuck },
                 predicate_field: :status,
                 defaults: { answer: nil, reasoning: nil, confidence: nil, token_usage: nil },
                 category: :metacognition, description: "Fired when step evaluation completes"

    # Refinement events (consolidated: RefinementCompleted + MixedRefinementCompleted)
    define_event :Refinement,
                 fields: %i[phase iterations improved confidence cross_model],
                 predicates: { completed: :completed, cross_model_completed: :cross_model_completed },
                 predicate_field: :phase,
                 defaults: { confidence: nil, cross_model: nil },
                 category: :metacognition, description: "Fired during refinement lifecycle"

    # Reflection events (learning from failures)
    define_event :ReflectionRecorded,
                 fields: %i[outcome reflection],
                 predicates: { failure: :failure, success: :success },
                 predicate_field: :outcome,
                 category: :metacognition, description: "Fired when a reflection is recorded"

    # Drift detection events (consolidated: GoalDriftDetected + PlanDivergence)
    define_event :DriftDetected,
                 fields: %i[phase level task_relevance off_topic_count],
                 predicates: { goal: :goal, plan: :plan },
                 predicate_field: :phase,
                 category: :metacognition, description: "Fired when goal or plan drift is detected"

    # Completion validation events
    define_event :CompletionRejected,
                 fields: %i[reason guidance],
                 defaults: { guidance: nil },
                 category: :metacognition, description: "Fired when a completion attempt is rejected"

    # Control flow events for Fiber-based bidirectional execution
    define_event :ControlYielded,
                 fields: %i[request_type request_id prompt],
                 predicates: { user_input: :user_input, confirmation: :confirmation,
                               sub_agent_query: :sub_agent_query },
                 predicate_field: :request_type,
                 category: :control, description: "Fired when the agent yields control for input",
                 tier: :user

    define_event :ControlResumed,
                 fields: %i[request_id approved value],
                 defaults: { value: nil },
                 category: :control, description: "Fired when execution resumes after yielding",
                 tier: :user

    # Repetition detection events (loop prevention)
    define_event :RepetitionDetected,
                 fields: %i[pattern count guidance],
                 predicates: { tool_call: :tool_call, code_action: :code_action, observation: :observation },
                 predicate_field: :pattern,
                 category: :metacognition, description: "Fired when repetition pattern is detected"

    # Tool isolation events (consolidated: ToolIsolationStarted + ToolIsolationCompleted + ResourceViolation)
    define_event :ToolIsolation,
                 fields: %i[tool_name phase isolation_mode resource_limits outcome metrics error_class
                            resource_type limit_value actual_value message],
                 predicates: { started: :started, completed: :completed, resource_violation: :resource_violation },
                 predicate_field: :phase,
                 freeze: %i[resource_limits metrics],
                 defaults: { isolation_mode: nil, resource_limits: nil, outcome: nil, metrics: nil,
                             error_class: nil, resource_type: nil, limit_value: nil, actual_value: nil,
                             message: nil },
                 category: :tools, description: "Fired during tool isolation lifecycle"

    # Model generation events (consolidated: ModelGenerateRequested + ModelGenerateCompleted)
    define_event :ModelGeneration,
                 fields: %i[model_id phase message_count has_tools temperature
                            duration_ms token_usage has_tool_calls outcome correlation_id],
                 predicates: { requested: :requested, completed: :completed },
                 predicate_field: :phase,
                 freeze: [:token_usage],
                 defaults: { message_count: nil, has_tools: false, temperature: nil,
                             duration_ms: nil, token_usage: nil, has_tool_calls: false, outcome: nil,
                             correlation_id: nil },
                 category: :models, description: "Fired during model generation lifecycle",
                 tier: :user

    # Goal tracking events (consolidated: GoalCreated + GoalProgress + GoalCompleted)
    define_event :GoalLifecycle,
                 fields: %i[goal phase parent_id previous_progress evidence],
                 predicates: { created: :created, progress: :progress, completed: :completed },
                 predicate_field: :phase,
                 defaults: { parent_id: nil, previous_progress: nil, evidence: nil },
                 category: :goals, description: "Fired during goal lifecycle transitions"

    # Planning events (consolidated: PlanGenerated + PlanUpdated)
    define_event :PlanEvent,
                 fields: %i[plan phase step_count model_id previous_plan reason step_number],
                 predicates: { generated: :generated, updated: :updated },
                 predicate_field: :phase,
                 defaults: { step_count: nil, model_id: nil, previous_plan: nil,
                             reason: nil, step_number: nil },
                 category: :planning, description: "Fired during plan lifecycle"

    # Code execution events (consolidated: CodeGenerated + CodeExecutionStarted + CodeExecutionFinished)
    define_event :CodeExecution,
                 fields: %i[phase code code_hash language step_number model_id
                            isolation_mode outcome duration_ms output error_class correlation_id],
                 predicates: { generated: :generated, started: :started, finished: :finished },
                 predicate_field: :phase,
                 defaults: { code: nil, code_hash: nil, language: nil, step_number: nil, model_id: nil,
                             isolation_mode: nil, outcome: nil, duration_ms: nil, output: nil,
                             error_class: nil, correlation_id: nil },
                 category: :execution, description: "Fired during code execution lifecycle"

    # Context compression events (memory management)
    define_event :ContextCompressed,
                 fields: %i[steps_compressed tokens_saved new_usage_percent],
                 defaults: { tokens_saved: 0, new_usage_percent: nil },
                 category: :lifecycle, description: "Fired when context memory is compressed"

    # Token-level streaming events (high frequency)
    define_event :ModelTokenGenerated,
                 fields: %i[token step_number accumulated_content],
                 defaults: { accumulated_content: nil },
                 category: :models, description: "Fired when a model generates a token during streaming"

    # Builder configuration events
    define_event :AgentConfigured,
                 fields: %i[agent_name tools model_purposes],
                 freeze: %i[tools model_purposes],
                 category: :lifecycle, description: "Fired when an agent is configured via builder"
  end
end
# rubocop:enable Metrics/ModuleLength

# Load additional event categories after module is defined
require_relative "events/reliability"
require_relative "events/orchestration"
require_relative "events/phase_d"
require_relative "events/task_coordination"
require_relative "events/capability"

# Legacy aliases — maps old symbol names to convention-derived names.
# These will be removed once all emit/on sites are updated to use canonical names.
require_relative "events/legacy_aliases"
