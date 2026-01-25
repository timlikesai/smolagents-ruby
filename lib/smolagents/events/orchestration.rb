module Smolagents
  module Events
    # Work Queue Events - Generalized work item lifecycle tracking
    #
    # These events enable observability of work items as they flow through
    # the orchestration system, from queue entry to worker completion.

    # Emitted when a work item is added to the work queue.
    define_event :WorkItemQueued,
                 fields: %i[work_item_id work_type priority queue_depth],
                 predicates: { model_generate: :model_generate, tool_call: :tool_call,
                               code_execution: :code_execution, sub_agent: :sub_agent },
                 predicate_field: :work_type

    # Emitted when a work item is dispatched to a worker for processing.
    define_event :WorkItemDispatched,
                 fields: %i[work_item_id work_type wait_time_ms worker_id],
                 defaults: { worker_id: nil }

    # Emitted when a work item completes (success, error, timeout, or cancelled).
    define_event :WorkItemCompleted,
                 fields: %i[work_item_id work_type outcome duration_ms error_class],
                 predicates: { success: :success, error: :error, timeout: :timeout, cancelled: :cancelled },
                 predicate_field: :outcome,
                 defaults: { error_class: nil }

    # Agent Step Events - Step-level execution tracking for event-driven agents

    # Emitted when an agent step is requested (before model generation).
    define_event :AgentStepRequested,
                 fields: %i[agent_id step_number task message_count],
                 defaults: { message_count: nil }

    # Code Execution Events - Sandbox execution lifecycle

    # Emitted before code is sent to the sandbox executor.
    define_event :CodeExecutionRequested,
                 fields: %i[agent_id step_number code_hash authorized_imports],
                 freeze: [:authorized_imports],
                 defaults: { authorized_imports: [] }

    # Emitted after code execution completes in the sandbox.
    define_event :CodeExecutionCompleted,
                 fields: %i[agent_id step_number outcome duration_ms output_size error_class],
                 predicates: { success: :success, error: :error, timeout: :timeout },
                 predicate_field: :outcome,
                 defaults: { output_size: nil, error_class: nil }

    # Sub-Agent Request Events - Parallel agent orchestration

    # Emitted when a sub-agent spawn is requested (before agent creation).
    # Complements SubAgentLaunched (which fires after creation).
    define_event :SubAgentRequested,
                 fields: %i[parent_id agent_name task priority],
                 defaults: { priority: :normal }

    # Orchestrator Lifecycle Events

    # Emitted when the orchestrator starts.
    define_event :OrchestratorStarted,
                 fields: %i[orchestrator_id]

    # Emitted when the orchestrator stops.
    define_event :OrchestratorStopped,
                 fields: %i[orchestrator_id]

    # Emitted when orchestrator dispatches work to a worker.
    define_event :OrchestratorDispatch,
                 fields: %i[orchestrator_id work_item_id work_type]

    # Async Task Events - Event-driven agent execution

    # Emitted when an async task run begins.
    define_event :TaskStarted,
                 fields: %i[run_id task]
  end
end
