module Smolagents
  module Events
    # Task coordination events for declarative task management.
    #
    # CoordTaskCreated captures definition-time data (description, dependencies).
    # CoordTaskLifecycle tracks runtime phases (started, completed, failed, etc.).
    #
    # @see Concerns::Agents::TaskCoordination
    # @see Concerns::Orchestration::WaveScheduler

    define_event :CoordTaskCreated,
                 fields: %i[task_id description priority dependencies active_form],
                 freeze: %i[dependencies],
                 defaults: { priority: nil, dependencies: [], active_form: nil },
                 category: :coordination,
                 description: "Fired when a coordinated task is declared"

    define_event :CoordTaskLifecycle,
                 fields: %i[task_id phase priority active_form
                            result duration_ms error recoverable work_item_id
                            elapsed progress_percent subtask_count blocked_by],
                 predicates: { started: :started, completed: :completed,
                               failed: :failed, dispatched: :dispatched,
                               progress: :progress },
                 predicate_field: :phase,
                 freeze: %i[blocked_by],
                 defaults: { priority: nil, active_form: nil, result: nil,
                             duration_ms: nil, error: nil, recoverable: false,
                             work_item_id: nil, elapsed: nil, progress_percent: nil,
                             subtask_count: 0, blocked_by: [] },
                 category: :coordination,
                 description: "Fired during task runtime lifecycle transitions"

    define_event :CoordWaveLifecycle,
                 fields: %i[wave_number phase task_count total_waves duration_ms],
                 predicates: { started: :started, completed: :completed },
                 predicate_field: :phase,
                 defaults: { total_waves: nil, duration_ms: nil },
                 category: :coordination,
                 description: "Fired during wave lifecycle transitions"
  end
end
