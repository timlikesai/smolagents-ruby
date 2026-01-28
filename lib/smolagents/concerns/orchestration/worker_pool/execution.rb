module Smolagents
  module Concerns
    module Orchestration
      module WorkerPool
        # Work submission and execution for the worker pool.
        module Execution
          # Submits work to the pool.
          #
          # @param work [Proc, Hash, nil] Work to execute (proc, work_item hash, or block)
          # @yield Block to execute if no work proc provided
          # @return [self]
          # @raise [PoolNotRunningError] If pool is not started
          def submit(work = nil, &block)
            # Normalize to work_item hash with optional callbacks
            work_item = normalize_work_item(work, block)
            raise ArgumentError, "Work required (proc or block)" unless work_item[:work]
            raise PoolNotRunningError, "Pool not running" unless @pool_running

            @work_queue.push(work_item)
            self
          end

          private

          def normalize_work_item(work, block)
            case work
            when Hash
              work
            when Proc
              { work:, on_complete: nil, on_error: nil }
            else
              { work: block, on_complete: nil, on_error: nil }
            end
          end

          public

          # Submits work and waits for completion.
          #
          # @yield Block to execute
          # @return [Object] Result of the work
          # @raise [StandardError] If work raises an error
          # rubocop:disable Metrics/MethodLength -- event-driven sync via Queue requires setup/teardown
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

            result_queue.pop rescue nil # rubocop:disable Style/RescueModifier -- safe nil on empty queue after error
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
          def submit_async(on_complete: nil, on_error: nil, &block)
            # Wrap work with callbacks in a hash so execute_work can handle them
            # in the correct order (count first, then callback)
            work_item = {
              work: block,
              on_complete:,
              on_error:
            }
            submit(work_item)
          end
        end

        # Raised when submitting to a non-running pool.
        class PoolNotRunningError < StandardError; end
      end
    end
  end
end
