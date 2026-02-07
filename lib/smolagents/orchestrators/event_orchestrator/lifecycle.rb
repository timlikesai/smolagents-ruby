module Smolagents
  module Orchestrators
    class EventOrchestrator
      # Lifecycle management for the event orchestrator.
      #
      # Handles starting, stopping, and graceful shutdown of all
      # orchestrator components including work queue and worker pool.
      module Lifecycle
        # Starts the orchestrator.
        #
        # Enables work queue, starts worker pool, and begins event processing.
        #
        # @return [self]
        def start
          @lifecycle_mutex.synchronize do
            return self if @running

            @running = true
            enable_work_queue(max_depth: @config.queue_depth)
            start_pool
            start_event_loop
          end
          emit(Events::OrchestratorLifecycle.create(orchestrator_id: @id, phase: :started))
          self
        end

        # Stops the orchestrator immediately.
        #
        # @return [self]
        def stop
          @lifecycle_mutex.synchronize do
            return self unless @running

            @running = false
            stop_event_loop
            disable_work_queue
            shutdown_pool(timeout: 1)
          end
          emit(Events::OrchestratorLifecycle.create(orchestrator_id: @id, phase: :stopped))
          self
        end

        # Gracefully shuts down the orchestrator.
        #
        # Drains pending work, waits for completion, then stops.
        #
        # @param timeout [Numeric] Maximum seconds to wait
        # @return [self]
        def graceful_shutdown(timeout: 30)
          deadline = Time.now + timeout
          wait_for_drain(deadline)
          stop_event_loop
          disable_work_queue
          remaining = [deadline - Time.now, 0].max
          shutdown_pool(timeout: remaining)
          @running = false
          emit(Events::OrchestratorLifecycle.create(orchestrator_id: @id, phase: :stopped))
          self
        end

        # Check if orchestrator is running.
        # @return [Boolean]
        def running? = @running

        private

        def start_event_loop
          @event_thread = Thread.new { event_processing_loop }
          @event_thread.name = "orchestrator-events-#{@id[0..7]}"
        end

        def stop_event_loop
          @event_queue&.push(:shutdown)
          @event_thread&.join(1)
          @event_thread = nil
        end

        def event_processing_loop
          loop do
            event = @event_queue.pop
            break if event == :shutdown

            route_event(event)
          rescue StandardError => e
            handle_event_error(e, event)
          end
        end

        def handle_event_error(error, event)
          emit_error(error, context: { event_class: event.class.name })
        end

        def wait_for_drain(deadline)
          @drain_mutex ||= Mutex.new
          @drain_cv ||= ConditionVariable.new

          @drain_mutex.synchronize do
            until work_queue_depth.zero? || Time.now >= deadline
              remaining = deadline - Time.now
              break if remaining <= 0

              @drain_cv.wait(@drain_mutex, remaining)
            end
          end
        end

        # Called by workers when work completes to signal drain waiters.
        def signal_work_complete
          @drain_cv&.signal
        end
      end
    end
  end
end
