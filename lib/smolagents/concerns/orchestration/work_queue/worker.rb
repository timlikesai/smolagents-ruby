require_relative "dispatch"

module Smolagents
  module Concerns
    module Orchestration
      module WorkQueue
        # Background worker thread that processes work items by priority.
        module Worker
          include Dispatch

          MAX_WORK_ITERATIONS = 100_000
          SHUTDOWN_TIMEOUT = 5

          private

          def start_work_worker
            @work_signal = ConditionVariable.new
            @work_mutex = Mutex.new
            @worker_thread = Thread.new { work_processing_loop }
            @worker_thread.name = "WorkQueue-Worker-#{object_id}"
          end

          def stop_work_worker
            @priority_queues&.dig(:critical)&.push(nil) # Poison pill
            signal_work_available
            # Worker will exit when it receives the poison pill (nil) from the queue.
            # With proper signaling, workers respond immediately - no timeout needed.
            @worker_thread&.join
            @worker_thread = nil
          end

          def signal_work_available
            @work_mutex&.synchronize { @work_signal&.signal }
          end

          def work_processing_loop
            MAX_WORK_ITERATIONS.times do
              break unless @work_queue_enabled

              work_item = dequeue_next_work
              break if work_item.nil?

              process_work_item(work_item)
            end
          rescue StandardError => e
            warn "WorkQueue worker error: #{e.message}" if $DEBUG
          end

          def dequeue_next_work
            item = try_dequeue_from_priorities
            return item if item

            wait_for_work
            try_dequeue_from_priorities
          end

          def try_dequeue_from_priorities
            PRIORITIES.each do |priority|
              queue = @priority_queues[priority]
              return queue.pop(true) if queue.size.positive?
            rescue ThreadError
              next
            end
            nil
          end

          def wait_for_work
            @work_mutex.synchronize { @work_signal.wait(@work_mutex) }
          end

          def process_work_item(work_item)
            @work_processing = true
            wait_time_ms = (work_item.wait_time * 1000).to_i
            update_work_stats(work_item, wait_time_ms)
            emit_work_dispatched(work_item, wait_time_ms)
            execute_work(work_item)
          ensure
            @work_processing = false
          end

          def execute_work(work_item)
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            result = check_deadline_and_execute(work_item, start_time)
            complete_work(work_item, result)
          rescue StandardError => e
            handle_work_error(work_item, e, start_time)
          end

          def check_deadline_and_execute(work_item, start_time)
            return Types::WorkResult.timeout(work_item_id: work_item.id, duration_ms: 0) if work_item.expired?

            value = dispatch_work(work_item)
            build_work_result(work_item, value, elapsed_ms(start_time))
          end

          def handle_work_error(work_item, error, start_time)
            result = Types::WorkResult.error(
              work_item_id: work_item.id, error:, duration_ms: elapsed_ms(start_time)
            )
            complete_work(work_item, result)
          end

          def complete_work(work_item, work_result)
            emit_work_completed(work_result, work_item.type)
            invoke_callback(work_item.id, work_result)
          end

          def invoke_callback(work_item_id, result)
            callback = @work_callbacks&.delete(work_item_id)
            callback&.call(result)
          end

          def update_work_stats(work_item, wait_time_ms)
            @work_stats[:mutex].synchronize do
              @work_stats[:wait_times] << wait_time_ms
              @work_stats[:total] += 1
              @work_stats[:by_type][work_item.type] += 1
            end
          end
        end
      end
    end
  end
end
