module Smolagents
  module Concerns
    module Orchestration
      module WorkerPool
        # Work submission and execution for the worker pool.
        module Execution
          # Submits work to the pool.
          #
          # @param work [Proc, nil] Work to execute (or provide block)
          # @yield Block to execute if no work proc provided
          # @return [self]
          # @raise [PoolNotRunningError] If pool is not started
          def submit(work = nil, &block)
            executable = work || block
            raise ArgumentError, "Work required (proc or block)" unless executable
            raise PoolNotRunningError, "Pool not running" unless @pool_running

            @work_queue.push(executable)
            self
          end

          # Submits work and waits for completion.
          #
          # @yield Block to execute
          # @return [Object] Result of the work
          # @raise [StandardError] If work raises an error
          # rubocop:disable Metrics/MethodLength -- sync queue logic
          def submit_sync
            result_queue = Thread::Queue.new
            error = nil

            submit do
              result_queue.push(yield)
            rescue StandardError => e
              error = e
              result_queue.push(nil)
            end

            result_queue.pop
            raise error if error

            result_queue.pop rescue nil # rubocop:disable Style/RescueModifier
          end
          # rubocop:enable Metrics/MethodLength

          # Submits multiple work items.
          #
          # @param items [Array<Proc>] Work items to submit
          # @return [self]
          def submit_batch(items)
            items.each { |work| submit(work) }
            self
          end

          # Submits work with callback on completion.
          #
          # @yield Block to execute
          # @param on_complete [Proc] Called with result on success
          # @param on_error [Proc] Called with error on failure
          # @return [self]
          def submit_async(on_complete: nil, on_error: nil)
            submit do
              result = yield
              on_complete&.call(result)
            rescue StandardError => e
              on_error&.call(e)
              raise
            end
          end
        end

        # Raised when submitting to a non-running pool.
        class PoolNotRunningError < StandardError; end
      end
    end
  end
end
