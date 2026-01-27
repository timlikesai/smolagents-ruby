module Smolagents
  module Events
    # Task coordination events for declarative task management.
    #
    # These events support the task coordination system, enabling
    # progress tracking, dependency resolution, and wave execution.
    #
    # @see Concerns::Agents::TaskCoordination
    # @see Concerns::Orchestration::WaveScheduler

    # Emitted when a task is declared in the coordinator.
    define_event :TaskCreatedEvent,
                 fields: %i[task_id description priority dependencies],
                 freeze: [:dependencies],
                 defaults: { dependencies: [] }

    # Emitted when a task starts executing.
    define_event :TaskStartedEvent,
                 fields: %i[task_id active_form]

    # Emitted when a task completes successfully.
    define_event :TaskCompletedEvent,
                 fields: %i[task_id result duration_ms],
                 defaults: { result: nil, duration_ms: nil }

    # Emitted when a task fails with an error.
    define_event :TaskFailedEvent,
                 fields: %i[task_id error recoverable],
                 defaults: { recoverable: false }

    # Emitted when a task is blocked by dependencies.
    define_event :TaskBlockedEvent,
                 fields: %i[task_id blocked_by],
                 freeze: [:blocked_by]

    # Emitted when a task becomes unblocked.
    define_event :TaskUnblockedEvent,
                 fields: %i[task_id unblocked_by]

    # Emitted when a task is cancelled.
    define_event :TaskCancelledEvent,
                 fields: %i[task_id reason],
                 defaults: { reason: nil }

    # Emitted when a task is dispatched to a work queue.
    define_event :TaskDispatchedEvent,
                 fields: %i[task_id priority work_item_id]

    # Emitted for periodic progress updates.
    define_event :TaskProgressEvent,
                 fields: %i[task_id active_form elapsed progress_percent subtask_count blocked_by],
                 freeze: [:blocked_by],
                 defaults: { subtask_count: 0, blocked_by: [] }

    # Emitted when a wave of parallel tasks starts.
    define_event :WaveStartedEvent,
                 fields: %i[wave_number task_count total_waves]

    # Emitted when a wave completes all its tasks.
    define_event :WaveCompletedEvent,
                 fields: %i[wave_number task_count duration_ms],
                 defaults: { duration_ms: nil }

    # Emitted when task priority changes.
    define_event :TaskPriorityChangedEvent,
                 fields: %i[task_id old_priority new_priority reason],
                 defaults: { reason: nil }

    # Emitted when overall task status changes.
    define_event :TaskStatusChangedEvent,
                 fields: %i[total completed open blocked in_progress]
  end
end
