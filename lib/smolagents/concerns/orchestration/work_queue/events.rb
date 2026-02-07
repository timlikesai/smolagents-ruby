module Smolagents
  module Concerns
    module Orchestration
      module WorkQueue
        # Event emission for work queue lifecycle.
        module QueueEvents
          include Events::Emitter

          private

          def emit_work_queued(work_item)
            emit(Events::WorkItemLifecycle.create(
                   phase: :queued,
                   work_item_id: work_item.id,
                   work_type: work_item.type,
                   priority: work_item.priority,
                   queue_depth: work_queue_depth
                 ))
          end

          def emit_work_dispatched(work_item, wait_time_ms)
            emit(Events::WorkItemLifecycle.create(
                   phase: :dispatched,
                   work_item_id: work_item.id,
                   work_type: work_item.type,
                   wait_time_ms:,
                   worker_id: Thread.current.name
                 ))
          end

          def emit_work_completed(work_result, work_type)
            emit(Events::WorkItemLifecycle.create(
                   phase: :completed,
                   work_item_id: work_result.work_item_id,
                   work_type: work_type || :unknown,
                   outcome: work_result.outcome,
                   duration_ms: work_result.duration_ms,
                   error_class: work_result.error&.class&.name
                 ))
          end
        end
      end
    end
  end
end
