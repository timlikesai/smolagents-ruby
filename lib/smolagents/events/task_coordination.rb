module Smolagents
  module Events
    # Task coordination events for declarative task management.
    # CoordTaskLifecycle expanded to absorb CoordTaskDispatched and CoordTaskProgress.
    #
    # @see Concerns::Agents::TaskCoordination
    # @see Concerns::Orchestration::WaveScheduler

    define_event :CoordTaskLifecycle,
                 fields: %i[task_id phase description priority dependencies active_form
                            result duration_ms error recoverable work_item_id
                            elapsed progress_percent subtask_count blocked_by],
                 predicates: { created: :created, started: :started,
                               completed: :completed, failed: :failed,
                               dispatched: :dispatched, progress: :progress },
                 predicate_field: :phase,
                 freeze: %i[dependencies blocked_by],
                 defaults: { description: nil, priority: nil, dependencies: [],
                             active_form: nil, result: nil, duration_ms: nil,
                             error: nil, recoverable: false, work_item_id: nil,
                             elapsed: nil, progress_percent: nil, subtask_count: 0,
                             blocked_by: [] },
                 category: :coordination,
                 description: "Fired during task lifecycle transitions"

    define_event :CoordWaveLifecycle,
                 fields: %i[wave_number phase task_count total_waves duration_ms],
                 predicates: { started: :started, completed: :completed },
                 predicate_field: :phase,
                 defaults: { total_waves: nil, duration_ms: nil },
                 category: :coordination,
                 description: "Fired during wave lifecycle transitions"
  end
end
