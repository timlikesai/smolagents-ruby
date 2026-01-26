module Smolagents
  module Concerns
    module Orchestration
      module WorkQueue
        # Queue operations: enqueue, dequeue, priority handling, capacity validation.
        module Operations
          # Enqueue a work item with optional callback for completion.
          #
          # @param work_item [WorkItem] The work item to enqueue
          # @yield [WorkResult] Called when work completes
          # @return [String] The work item ID for tracking
          # @raise [AgentError] If queue is full
          def enqueue_work(work_item, &callback)
            raise AgentError, "Work queue not enabled" unless @work_queue_enabled

            validate_work_capacity!
            store_callback(work_item.id, callback) if callback
            enqueue_by_priority(work_item)
            emit_work_queued(work_item)
            work_item.id
          end

          # Enqueue and wait for result (blocking).
          #
          # @param work_item [WorkItem] The work item to process
          # @return [WorkResult] The work result
          def enqueue_work_sync(work_item)
            result_queue = Thread::Queue.new
            enqueue_work(work_item) { |result| result_queue.push(result) }
            result_queue.pop
          end

          # Clear all pending work items.
          # @return [void]
          def clear_work_queue
            @priority_queues&.each_value(&:clear)
            @work_callbacks&.clear
          end

          # Cancel a pending work item.
          # @param work_item_id [String] ID of the work item to cancel
          # @return [Boolean] True if item was found and cancelled
          # rubocop:disable Naming/PredicateMethod -- action method, returns success status
          def remove_work(work_item_id)
            return false unless @priority_queues

            PRIORITIES.each do |priority|
              removed = remove_from_priority_queue(@priority_queues[priority], work_item_id)
              return true if removed
            end
            false
          end
          # rubocop:enable Naming/PredicateMethod

          private

          def validate_work_capacity!
            return unless @work_queue_max_depth && work_queue_depth >= @work_queue_max_depth

            raise AgentError, "Work queue full (#{work_queue_depth}/#{@work_queue_max_depth})"
          end

          def store_callback(work_item_id, callback)
            @work_callbacks[work_item_id] = callback
          end

          def enqueue_by_priority(work_item)
            queue = @priority_queues[work_item.priority] || @priority_queues[:normal]
            queue.push(work_item)
            signal_work_available if respond_to?(:signal_work_available, true)
          end

          # rubocop:disable Naming/PredicateMethod -- action method, returns success status
          def remove_from_priority_queue(queue, work_item_id)
            items = drain_work_queue(queue)
            found = items.reject! { |item| item.id == work_item_id }
            items.each { |item| queue.push(item) }
            emit_cancellation(work_item_id) if found
            !found.nil?
          end
          # rubocop:enable Naming/PredicateMethod

          def emit_cancellation(work_item_id)
            emit_work_completed(
              Types::WorkResult.cancelled(work_item_id:, duration_ms: 0),
              nil
            )
          end

          def drain_work_queue(queue)
            items = []
            while queue.size.positive?
              begin
                items << queue.pop(true)
              rescue ThreadError
                break
              end
            end
            items
          end
        end
      end
    end
  end
end
