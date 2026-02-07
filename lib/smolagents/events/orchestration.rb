module Smolagents
  module Events
    # Work item events (consolidated: WorkItemQueued + WorkItemDispatched + WorkItemCompleted)
    define_event :WorkItemLifecycle,
                 fields: %i[work_item_id work_type phase priority queue_depth
                            wait_time_ms worker_id outcome duration_ms error_class],
                 predicates: { queued: :queued, dispatched: :dispatched, completed: :completed },
                 predicate_field: :phase,
                 defaults: { priority: nil, queue_depth: nil, wait_time_ms: nil,
                             worker_id: nil, outcome: nil, duration_ms: nil, error_class: nil },
                 category: :orchestration, description: "Fired during work item lifecycle transitions"

    # Agent Step Events
    define_event :AgentStepRequested,
                 fields: %i[agent_id step_number task message_count],
                 defaults: { message_count: nil },
                 category: :orchestration, description: "Fired when an agent step is requested"

    # Orchestrator Lifecycle Events
    define_event :OrchestratorLifecycle,
                 fields: %i[orchestrator_id phase],
                 predicates: { started: :started, stopped: :stopped },
                 predicate_field: :phase,
                 category: :orchestration,
                 description: "Fired during orchestrator lifecycle transitions"
  end
end
