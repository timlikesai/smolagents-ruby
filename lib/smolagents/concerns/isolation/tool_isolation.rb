module Smolagents
  module Concerns
    module Isolation
      # Resource-bounded tool execution with timeout and violation handling.
      #
      # Provides isolated execution of tool calls with configurable resource
      # limits, timeout handling, and violation callbacks. Uses caller-controlled
      # callbacks for timeout and violation handling, following the pattern
      # established by {ToolRetry}.
      #
      # @example Basic isolation with defaults
      #   result = with_tool_isolation(tool_name: "search") { api_call }
      #
      # @example With custom limits and callbacks
      #   with_tool_isolation(
      #     tool_name: "compute",
      #     limits: ResourceLimits.new(timeout_seconds: 30.0, ...),
      #     on_timeout: ->(info) { log_timeout(info) },
      #     on_violation: ->(info) { log_violation(info) }
      #   ) { heavy_computation }
      #
      # @see Types::Isolation::ResourceLimits For limit configuration
      # @see Events::ToolIsolationStarted For start event
      module ToolIsolation
        include Events::Emitter

        # Default resource limits for tool isolation.
        # @return [Types::Isolation::ResourceLimits] Default limits
        def self.default_limits = Types::Isolation::ResourceLimits.default

        # Executes a block with resource isolation and limit enforcement.
        #
        # @param tool_name [String] Name of the tool being isolated
        # @param limits [Types::Isolation::ResourceLimits] Resource limits
        # @param isolation_mode [Symbol] :thread (default) or :fiber
        # @param on_timeout [#call, nil] Callback when timeout occurs
        # @param on_violation [#call, nil] Callback when resource limit exceeded
        # @yield Block to execute in isolation
        # @return [Object] Result of the block
        # @raise [Types::Isolation::TimeoutError] When execution times out
        def with_tool_isolation(tool_name:, limits: ToolIsolation.default_limits, isolation_mode: :thread,
                                on_timeout: nil, on_violation: nil, &)
          emit_isolation_started(tool_name, isolation_mode, limits)
          result = execute_isolated(tool_name, limits, isolation_mode, on_violation, &)
          emit_isolation_completed(tool_name, :success, result.metrics)
          result.value
        rescue Types::Isolation::TimeoutError => e
          handle_timeout(tool_name, e, on_timeout)
        rescue StandardError => e
          emit_isolation_completed(tool_name, :error, nil, e.class.name)
          raise
        end

        private

        def execute_isolated(tool_name, limits, mode, on_violation, &)
          executor = mode == :fiber ? FiberExecutor : ThreadExecutor
          result = executor.execute(limits:, &)
          handle_result(tool_name, result, limits, on_violation)
        end

        def handle_result(tool_name, result, limits, on_violation)
          return result if result.success?
          raise result.error if result.timeout? || result.error?

          handle_violation(tool_name, result.metrics, limits, result.error, on_violation)
        end

        def handle_timeout(tool_name, error, on_timeout)
          metrics = Types::Isolation::ResourceMetrics.zero
          on_timeout&.call(build_timeout_info(tool_name, error))
          emit_isolation_completed(tool_name, :timeout, metrics)
          raise error
        end

        def handle_violation(tool_name, metrics, limits, error, on_violation)
          violation_info = build_violation_info(tool_name, metrics, limits)
          on_violation&.call(violation_info)
          emit_resource_violation(tool_name, violation_info)
          emit_isolation_completed(tool_name, :violation, metrics, error.class.name)
          raise error
        end

        def build_timeout_info(tool_name, error) = { tool_name:, error:, message: error.message }

        def build_violation_info(tool_name, metrics, limits)
          ViolationInfoBuilder.build(tool_name, metrics, limits)
        end

        def emit_isolation_started(tool_name, mode, limits)
          emit(Events::ToolIsolationStarted.create(
                 tool_name:, isolation_mode: mode, resource_limits: limits.to_h
               ))
        end

        def emit_isolation_completed(tool_name, outcome, metrics, error_class = nil)
          emit(Events::ToolIsolationCompleted.create(
                 tool_name:, outcome:, metrics: metrics&.to_h, error_class:
               ))
        end

        def emit_resource_violation(tool_name, info)
          emit(Events::ResourceViolation.create(
                 tool_name:,
                 resource_type: info[:resource_type],
                 limit_value: info[:limit_value],
                 actual_value: info[:actual_value],
                 message: info[:message]
               ))
        end
      end
    end
  end
end
