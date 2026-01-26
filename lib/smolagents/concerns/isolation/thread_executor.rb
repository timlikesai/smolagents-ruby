module Smolagents
  module Concerns
    module Isolation
      # Executes code in isolated thread with resource limits.
      #
      # Uses Thread.new + Thread.join(timeout) for safe timeout handling.
      # Avoids Timeout.timeout which uses Thread.raise (unsafe).
      #
      # @example Basic execution
      #   result = ThreadExecutor.execute { expensive_computation }
      #   result.success?  # => true
      #   result.value     # => computation result
      #
      # @example With custom limits
      #   limits = Types::Isolation::ResourceLimits.with_timeout(10.0)
      #   result = ThreadExecutor.execute(limits:) { slow_operation }
      #
      # @see Types::Isolation::IsolationResult For result types
      # @see Types::Isolation::ResourceLimits For limit configuration
      module ThreadExecutor
        module_function

        # Execute block in isolated thread with limits.
        #
        # @param limits [Types::Isolation::ResourceLimits] Resource constraints
        # @yield Block to execute in isolated thread
        # @return [Types::Isolation::IsolationResult] Execution result
        def execute(limits: Types::Isolation::ResourceLimits.default, &)
          start_time = monotonic_time
          thread = Thread.new(&)

          if thread.join(limits.timeout_seconds)
            build_success(thread.value, start_time)
          else
            handle_timeout(thread, start_time)
          end
        rescue StandardError => e
          build_error(e, start_time)
        end

        # @api private
        def build_success(value, start_time)
          metrics = build_metrics(start_time)
          Types::Isolation::IsolationResult.success(value:, metrics:)
        end

        # @api private
        def handle_timeout(thread, start_time)
          thread.kill
          metrics = build_metrics(start_time)
          Types::Isolation::IsolationResult.timeout(metrics:)
        end

        # @api private
        def build_error(error, start_time)
          metrics = build_metrics(start_time)
          Types::Isolation::IsolationResult.error(error:, metrics:)
        end

        # @api private
        def build_metrics(start_time)
          duration_ms = ((monotonic_time - start_time) * 1000).to_i
          Types::Isolation::ResourceMetrics.new(
            duration_ms:,
            memory_bytes: current_memory_bytes,
            output_bytes: 0
          )
        end

        # @api private
        def monotonic_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # @api private
        def current_memory_bytes
          GC.stat(:heap_live_slots) * 40 # Approximate bytes per slot
        rescue StandardError
          0
        end
      end
    end
  end
end
